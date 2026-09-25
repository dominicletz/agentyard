defmodule AgentYard.Agents.CLI do
  @moduledoc """
  Shared Port runner for command-line agent adapters.
  """

  alias AgentYard.Agents.{Event, StreamParser}

  def start(config, callback, provider, executables) do
    executable =
      case config[:sandbox_module] do
        AgentYard.Sandboxes.Docker -> List.first(executables)
        _ -> Enum.find_value(executables, &System.find_executable/1)
      end

    if executable do
      state = %{
        config: Map.put(config, :executable, executable),
        callback: callback,
        provider: provider,
        worker: nil
      }
      {:ok, launch(state)}
    else
      {:error, {:missing_executable, executables}}
    end
  end

  def follow_up(state, prompt) do
    state
    |> Map.update!(:config, &Map.put(&1, :prompt, prompt))
    |> launch()
    |> then(&{:ok, &1})
  end

  def cancel(%{worker: pid}) when is_pid(pid) do
    Process.unlink(pid)
    Process.exit(pid, :kill)
    :ok
  end

  def cancel(_), do: :ok

  defp launch(state) do
    executable = state.config[:executable] || find_executable(state.provider)
    parent = self()

    worker =
      spawn_link(fn ->
        port = open_port(state, executable)
        send(parent, {:cli_started, self()})
        read_port(port, state)
      end)

    %{state | worker: worker}
  end

  defp read_port(port, state) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        maybe_emit(line, state)
        read_port(port, state)

      {^port, {:data, {:noeol, line}}} ->
        maybe_emit(line, state)
        read_port(port, state)

      {^port, {:exit_status, 0}} ->
        state.callback.(Event.done())

      {^port, {:exit_status, status}} ->
        state.callback.(Event.error("Agent CLI exited with status #{status}"))
    end
  end

  defp maybe_emit(line, state) do
    case StreamParser.parse_line(line, state.provider) do
      {:ok, event} -> state.callback.(event)
      :ignore -> :ok
      {:error, reason} -> state.callback.(Event.error(inspect(reason)))
    end
  end

  defp port_options(state) do
    [
      :binary,
      :exit_status,
      {:line, 1_048_576},
      :stderr_to_stdout,
      {:args, args(state)},
      {:env, environment(state.config)}
    ]
  end

  defp args(state) do
    prompt = to_string(state.config[:prompt] || "")
    provider_args(state.provider, state.config, prompt)
  end

  defp provider_args(:claude_code, config, prompt) do
    ["-p", prompt, "--output-format", "stream-json", "--verbose"]
    |> add_option("--model", config[:model])
    |> add_option("--max-budget-usd", decimal_string(config[:budget_usd]))
    |> add_option("--append-system-prompt", config[:instructions])
    |> add_permission_mode(config[:permission_mode])
  end

  defp provider_args(:cursor_cli, config, prompt) do
    ["-p", prompt, "--output-format", "stream-json", "--verbose"]
    |> add_option("--model", config[:model])
    |> add_option("--instructions", config[:instructions])
    |> add_permission_mode(config[:permission_mode])
  end

  defp add_option(args, _name, nil), do: args
  defp add_option(args, _name, ""), do: args
  defp add_option(args, name, value), do: args ++ [name, to_string(value)]

  defp add_permission_mode(args, permission_mode) when permission_mode in [nil, "", "ask"],
    do: args

  defp add_permission_mode(args, "accept_edits"),
    do: add_option(args, "--permission-mode", "acceptEdits")

  defp add_permission_mode(args, "bypass"),
    do: add_option(args, "--permission-mode", "bypassPermissions")

  defp add_permission_mode(args, permission_mode),
    do: add_option(args, "--permission-mode", permission_mode)

  defp decimal_string(nil), do: nil
  defp decimal_string(%Decimal{} = value), do: Decimal.to_string(value)
  defp decimal_string(value), do: to_string(value)

  defp environment(config) do
    config
    |> Map.get(:env, %{})
    |> Enum.map(fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
  end

  defp open_port(state, executable) do
    case state.config[:sandbox_module] do
      module when is_atom(module) ->
        {:ok, port} = module.port(state.config, [executable | args(state)])
        port

      _ ->
        Port.open({:spawn_executable, executable}, port_options(state))
    end
  end

  defp find_executable(:claude_code), do: System.find_executable("claude")

  defp find_executable(:cursor_cli),
    do: System.find_executable("cursor-agent") || System.find_executable("agent")
end
