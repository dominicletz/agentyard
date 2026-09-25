defmodule AgentYard.Runs.RunProcess do
  @moduledoc """
  Per-run OTP process that connects adapters to persisted events.
  """

  use GenServer

  alias AgentYard.Agents.Event
  alias AgentYard.Runs

  def start_link(run_id) do
    GenServer.start_link(__MODULE__, run_id,
      name: {:via, Registry, {AgentYard.Runs.Registry, run_id}}
    )
  end

  @impl true
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

        {:ok, %{run: run, adapter: adapter_for(run), adapter_state: nil, failed: false},
         {:continue, :start}}
    end
  end

  @impl true
  def handle_continue(:start, state) do
    owner = self()
    config = adapter_config(state.run)

    with {:ok, prepared} <- state.adapter.prepare(config),
         {:ok, adapter_state} <-
           state.adapter.start(prepared, fn event -> send(owner, {:adapter_event, event}) end) do
      {:noreply, %{state | adapter_state: adapter_state}}
    else
      {:error, reason} ->
        {:stop, {:adapter_start_failed, reason}, mark_failed(state, inspect(reason))}
    end
  end

  @impl true
  def handle_info({:adapter_event, %Event{} = event}, state) do
    {:ok, record} = Runs.record_event(state.run, event)
    {:ok, run} = Runs.apply_event(state.run, event)
    state = %{state | run: run}
    Runs.broadcast(run, {:run_event, run.id, record})
    Runs.broadcast(run, {:run_updated, run})

    case event.type do
      "error" ->
        {:noreply, mark_failed(state, event.message || "Agent error")}

      "done" ->
        status = if state.failed, do: "failed", else: "succeeded"
        {:ok, run} = Runs.update_status(run, status, %{finished_at: DateTime.utc_now()})
        Runs.broadcast(run, {:run_updated, run})
        {:stop, :normal, %{state | run: run}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:adapter_event, _event}, state), do: {:noreply, state}
  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_call(:cancel, _from, state) do
    _ = if state.adapter_state, do: state.adapter.cancel(state.adapter_state), else: :ok
    {:ok, run} = Runs.update_status(state.run, "cancelled", %{finished_at: DateTime.utc_now()})
    event = Event.status("Run cancelled")
    {:ok, record} = Runs.record_event(run, event)
    Runs.broadcast(run, {:run_event, run.id, record})
    Runs.broadcast(run, {:run_updated, run})
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

  defp mark_failed(state, message) do
    {:ok, run} = Runs.update_status(state.run, "failed", %{error: message})
    Runs.broadcast(run, {:run_updated, run})
    %{state | run: run, failed: true}
  end

  defp adapter_for(%{session: %{agent_profile: %{provider: "claude_code"}}}),
    do: AgentYard.Agents.ClaudeCode

  defp adapter_for(%{session: %{agent_profile: %{provider: "cursor_cli"}}}),
    do: AgentYard.Agents.CursorCLI

  defp adapter_for(%{session: %{agent_profile: %{provider: "openrouter"}}}),
    do: AgentYard.Agents.OpenRouter

  defp adapter_for(_run), do: AgentYard.Agents.Fake

  defp adapter_config(%{prompt: prompt, session: %{agent_profile: profile}, id: run_id}) do
    %{
      prompt: prompt,
      run_id: run_id,
      model: profile.model,
      instructions: profile.instructions,
      permission_mode: profile.permission_mode,
      budget_usd: profile.budget_usd,
      env: %{}
    }
  end
end
