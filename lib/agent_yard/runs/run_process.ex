defmodule AgentYard.Runs.RunProcess do
  @moduledoc """
  Per-run OTP process that connects adapters to persisted events.
  """

  use GenServer

  alias AgentYard.Agents.{Event, Fake}
  alias AgentYard.Runs
  alias AgentYard.Runs.GitOrchestrator
  alias AgentYard.Sandboxes.{Docker, Local}
  alias AgentYard.Secrets

  def start_link(run_id) do
    GenServer.start_link(__MODULE__, run_id,
      name: {:via, Registry, {AgentYard.Runs.Registry, run_id}}
    )
  end

  def child_spec(run_id) do
    %{
      id: {__MODULE__, run_id},
      start: {__MODULE__, :start_link, [run_id]},
      restart: :temporary,
      type: :worker
    }
  end

  @impl true
  def init(run_id) do
    case Runs.get_run(run_id) do
      nil ->
        {:stop, :run_not_found}

      run ->
        {:ok, run} =
          Runs.update_status(run, "running", %{started_at: DateTime.utc_now(), error: nil})

        Runs.broadcast(run, {:run_updated, run})

        secret_values = Secrets.values_for_run(run.team_id, run.session.repository_id)

        {:ok,
         %{
           run: run,
           adapter: adapter_for(run),
           adapter_state: nil,
           failed: false,
           turns: 0,
           secret_values: secret_values,
           run_config: nil,
           sandbox: nil,
           timeout_ref: nil
         }, {:continue, :start}}
    end
  end

  @impl true
  def handle_continue(:start, state) do
    owner = self()
    config = adapter_config(state.run, state.secret_values)
    sandbox = sandbox_for(state.run)
    state = %{state | run_config: config, sandbox: sandbox}

    with {:ok, sandbox_config} <-
           sandbox.prepare(Map.put(config, :sandbox_module, sandbox)),
         {:ok, prepared, setup_events} <- GitOrchestrator.prepare(state.run, sandbox_config) do
      state =
        state
        |> Map.put(:run_config, prepared)
        |> persist_events([
          Event.status("Starting #{sandbox_name(sandbox)} sandbox") | setup_events
        ])

      start_adapter(state, prepared, owner)
    else
      {:error, reason} ->
        stop_failed(state, reason)
    end
  end

  defp start_adapter(state, prepared, owner) do
    case state.adapter.prepare(prepared) do
      {:ok, adapter_config} -> start_prepared_adapter(state, adapter_config, owner)
      {:error, reason} -> stop_failed(state, reason)
    end
  end

  defp start_prepared_adapter(state, adapter_config, owner) do
    callback = fn event -> send(owner, {:adapter_event, event}) end

    case state.adapter.start(adapter_config, callback) do
      {:ok, adapter_state} ->
        {:noreply,
         %{
           state
           | adapter_state: adapter_state,
             run_config: adapter_config,
             timeout_ref: schedule_timeout(state.run.timeout_seconds)
         }}

      {:error, reason} ->
        stop_failed(state, reason)
    end
  end

  @impl true
  def handle_info({:adapter_event, %Event{} = event}, state) do
    event = Event.mask(event, state.secret_values)
    state = persist_event(state, event)
    state = track_turn(state, event)

    case event.type do
      "done" ->
        complete_run(state)

      "error" ->
        {:noreply, mark_failed(state, event.message || "Agent error")}

      _ ->
        cond do
          max_turns_exceeded?(state) -> stop_for_turn_limit(state)
          budget_exceeded?(state.run) -> stop_for_budget(state)
          true -> {:noreply, state}
        end
    end
  end

  def handle_info({:adapter_event, _event}, state), do: {:noreply, state}

  def handle_info(:run_timeout, state) do
    message = "Run exceeded its #{state.run.timeout_seconds || 3600}s wall-clock timeout"
    _ = if state.adapter_state, do: state.adapter.cancel(state.adapter_state), else: :ok
    state = persist_event(state, Event.error(message))
    state = mark_failed(state, message, true)
    cleanup(state)
    {:stop, :normal, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_call(:cancel, _from, state) do
    _ = if state.adapter_state, do: state.adapter.cancel(state.adapter_state), else: :ok
    state = persist_event(state, Event.status("Run cancelled"))
    {:ok, run} = Runs.update_status(state.run, "cancelled", %{finished_at: DateTime.utc_now()})
    Runs.broadcast(run, {:run_updated, run})
    cleanup(%{state | run: run})
    {:stop, :normal, :ok, %{state | run: run}}
  end

  def handle_call({:follow_up, prompt}, _from, state) do
    owner = self()

    case state.adapter.follow_up(
           state.adapter_state,
           prompt,
           fn event -> send(owner, {:adapter_event, event}) end
         ) do
      {:ok, adapter_state} -> {:reply, :ok, %{state | adapter_state: adapter_state}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp complete_run(%{failed: true} = state), do: finish_run(state)

  defp complete_run(state) do
    state = persist_workspace_diff(state)

    case GitOrchestrator.finalize(state.run, state.run_config) do
      {:ok, change, events} ->
        state = persist_events(state, events)
        state = apply_change(state, change)
        finish_run(state)

      {:error, reason} ->
        message = safe_message(reason, state.secret_values)
        state = persist_event(state, Event.error("Could not publish changes: #{message}"))
        state = mark_failed(state, message, true)
        cleanup(state)
        {:stop, :normal, state}
    end
  end

  defp finish_run(state) do
    status = if state.failed, do: "failed", else: "succeeded"
    {:ok, run} = Runs.update_status(state.run, status, %{finished_at: DateTime.utc_now()})
    Runs.broadcast(run, {:run_updated, run})
    state = cancel_timeout(%{state | run: run})
    cleanup(state)
    {:stop, :normal, state}
  end

  defp stop_for_budget(state) do
    message = "Run stopped because budget exceeded (limit $#{budget(state.run)})"
    _ = if state.adapter_state, do: state.adapter.cancel(state.adapter_state), else: :ok
    state = persist_event(state, Event.error(message))
    state = mark_failed(state, message, true)
    cleanup(state)
    {:stop, :normal, state}
  end

  defp stop_for_turn_limit(state) do
    message = "Run stopped because maximum turns (#{state.run.max_turns}) was exceeded"
    _ = if state.adapter_state, do: state.adapter.cancel(state.adapter_state), else: :ok
    state = persist_event(state, Event.error(message))
    state = mark_failed(state, message, true)
    cleanup(state)
    {:stop, :normal, state}
  end

  defp stop_failed(state, reason) do
    message = safe_message(reason, state.secret_values)
    state = persist_event(state, Event.error(message))
    state = mark_failed(state, message, true)
    cleanup(state)
    {:stop, {:run_failed, reason}, state}
  end

  defp mark_failed(state, message, finish \\ false) do
    attrs = if finish, do: %{finished_at: DateTime.utc_now()}, else: %{}
    {:ok, run} = Runs.update_status(state.run, "failed", Map.put(attrs, :error, message))
    Runs.broadcast(run, {:run_updated, run})
    %{state | run: run, failed: true}
  end

  defp persist_events(state, events),
    do: Enum.reduce(events, state, &persist_event(&2, &1))

  defp persist_event(state, %Event{} = event) do
    event = Event.mask(event, state.secret_values)
    {:ok, record} = Runs.record_event(state.run, event)
    {:ok, run} = Runs.apply_event(state.run, event)
    Runs.broadcast(run, {:run_event, run.id, record})
    Runs.broadcast(run, {:run_updated, run})
    %{state | run: run}
  end

  defp persist_workspace_diff(%{run_config: config} = state) when is_map(config) do
    case GitOrchestrator.workspace_diff(config) do
      {:ok, diff} ->
        persist_event(state, Event.workspace_diff(diff))

      {:error, reason} ->
        persist_event(
          state,
          Event.status("Workspace diff unavailable: #{safe_message(reason, state.secret_values)}")
        )
    end
  end

  defp persist_workspace_diff(state), do: persist_event(state, Event.workspace_diff(""))

  defp track_turn(state, %Event{type: "tool_call"}), do: %{state | turns: state.turns + 1}
  defp track_turn(state, _event), do: state

  defp apply_change(state, nil), do: state

  defp apply_change(state, %{url: url}) do
    attrs =
      case state.run.session.repository.forge do
        "gitlab" -> %{merge_request_url: url}
        _ -> %{pr_url: url}
      end

    case Runs.update_run(state.run, attrs) do
      {:ok, run} ->
        Runs.broadcast(run, {:run_updated, run})
        %{state | run: run}

      {:error, _changeset} ->
        state
    end
  end

  defp cleanup(%{sandbox: nil}), do: :ok

  defp cleanup(%{sandbox: sandbox, run_config: config}) do
    _ = sandbox.cleanup(config || %{})
    _ = cleanup_mcp_config(config)
    :ok
  end

  defp cleanup_mcp_config(%{mcp_config_path: path}) when is_binary(path) do
    path
    |> Path.dirname()
    |> File.rm_rf()
  end

  defp cleanup_mcp_config(_config), do: :ok

  defp cancel_timeout(%{timeout_ref: nil} = state), do: state

  defp cancel_timeout(%{timeout_ref: ref} = state) do
    _ = Process.cancel_timer(ref)
    %{state | timeout_ref: nil}
  end

  defp schedule_timeout(nil), do: nil

  defp schedule_timeout(seconds) when is_integer(seconds) and seconds > 0,
    do: Process.send_after(self(), :run_timeout, seconds * 1_000)

  defp schedule_timeout(_seconds), do: nil

  defp budget_exceeded?(run) do
    case run.session.agent_profile.budget_usd do
      nil ->
        false

      budget ->
        Decimal.compare(run.cost_usd || Decimal.new("0"), budget) == :gt
    end
  end

  defp budget(%{session: %{agent_profile: %{budget_usd: budget}}}) when not is_nil(budget),
    do: Decimal.to_string(budget)

  defp budget(_run), do: "0"

  defp max_turns_exceeded?(%{run: %{max_turns: nil}}), do: false
  defp max_turns_exceeded?(%{run: %{max_turns: max_turns}, turns: turns}), do: turns > max_turns

  defp safe_message(reason, secrets) do
    reason
    |> inspect()
    |> Event.error()
    |> Event.mask(secrets)
    |> Map.get(:message)
  end

  defp adapter_for(%{session: %{agent_profile: %{provider: "claude_code"}}}),
    do: AgentYard.Agents.ClaudeCode

  defp adapter_for(%{session: %{agent_profile: %{provider: "cursor_cli"}}}),
    do: AgentYard.Agents.CursorCLI

  defp adapter_for(%{session: %{agent_profile: %{provider: "openrouter"}}}),
    do: AgentYard.Agents.OpenRouter

  defp adapter_for(%{session: %{agent_profile: %{provider: "fake"}}}), do: Fake
  defp adapter_for(_run), do: Fake

  defp sandbox_for(%{environment: "docker"}), do: Docker
  defp sandbox_for(_run), do: Local

  defp sandbox_name(Docker), do: "Docker"
  defp sandbox_name(Local), do: "local"
  defp sandbox_name(_), do: "configured"

  defp adapter_config(
         %{prompt: prompt, session: %{agent_profile: profile, repository: repository}} = run,
         env
       ) do
    %{
      prompt: prompt,
      run_id: run.id,
      model: profile.model,
      base_url: profile.base_url,
      mcp_servers: profile.mcp_servers || %{},
      instructions: profile.instructions,
      permission_mode: profile.permission_mode,
      budget_usd: profile.budget_usd,
      env: env,
      environment: run.environment,
      image: repository.environment_image,
      cpus: Application.get_env(:agentyard, :sandbox_cpus, 2),
      memory: Application.get_env(:agentyard, :sandbox_memory, "2g"),
      network: Application.get_env(:agentyard, :sandbox_network, "none"),
      network_allowlist: Application.get_env(:agentyard, :sandbox_network_allowlist, []),
      agent_provider: profile.provider,
      max_turns: run.max_turns,
      workspace_root: Application.get_env(:agentyard, :workspace_root)
    }
  end
end
