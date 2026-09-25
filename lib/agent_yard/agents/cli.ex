defmodule AgentYard.Agents.CLI do
  @moduledoc """
  Shared Port runner for command-line agent adapters.
  """

  alias AgentYard.Agents.{Event, StreamParser}

  def start(config, callback, provider, executables) do
    executable = Enum.find_value(executables, &System.find_executable/1)

    if executable do
      state = %{config: config, callback: callback, provider: provider, worker: nil}
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
    Process.exit(pid, :kill)
    :ok
  end

  def cancel(_), do: :ok

  defp launch(state) do
    executable = state.config[:executable] || find_executable(state.provider)
    parent = self()

    worker =
      spawn_link(fn ->
        port = Port.open({:spawn_executable, executable}, port_options(state))
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
    ["-p", prompt, "--output-format", "stream-json", "--verbose"]
  end

  defp environment(config) do
    config
    |> Map.get(:env, %{})
    |> Enum.map(fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
  end

  defp find_executable(:claude_code), do: System.find_executable("claude")

  defp find_executable(:cursor_cli),
    do: System.find_executable("cursor-agent") || System.find_executable("agent")
end
