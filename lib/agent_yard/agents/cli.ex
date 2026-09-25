defmodule AgentYard.Agents.CLI do
  @moduledoc """
  Shared Port runner for command-line agent adapters.
  """

  alias AgentYard.Agents.{Event, StreamParser}

  @doc """
  Materializes configured MCP servers inside the run workspace.

  The file is excluded from the repository so it can be mounted into Docker
  and passed to both supported CLI adapters without becoming a workspace
  change. Values remain in the runner filesystem only.
  """
  def prepare(config) do
    case config[:mcp_servers] do
      servers when is_map(servers) and map_size(servers) > 0 ->
        workspace = config[:workspace] || Path.join(System.tmp_dir!(), "agentyard")
        path = Path.join(workspace, ".agentyard/mcp.json")
        payload = if mcp_payload?(servers), do: servers, else: %{"mcpServers" => servers}

        with :ok <- File.mkdir_p(Path.dirname(path)),
             :ok <- File.write(path, Jason.encode!(payload)),
             :ok <- exclude_from_git(workspace) do
          {:ok, Map.put(config, :mcp_config_path, path)}
        end

      _ ->
        {:ok, config}
    end
  end

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

  @doc """
  Returns provider command arguments without opening a port.
  """
  def command_args(config, provider, prompt \\ nil) do
    prompt = to_string(prompt || config[:prompt] || "")
    provider_args(provider, config, prompt)
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
    command_args(state.config, state.provider)
  end

  defp provider_args(:claude_code, config, prompt) do
    ["-p", prompt, "--output-format", "stream-json", "--verbose"]
    |> add_option("--model", config[:model])
    |> add_option("--max-budget-usd", decimal_string(config[:budget_usd]))
    |> add_option("--append-system-prompt", config[:instructions])
    |> add_permission_mode(config[:permission_mode])
    |> add_option("--mcp-config", mcp_config_path(config))
  end

  defp provider_args(:cursor_cli, config, prompt) do
    ["-p", prompt, "--output-format", "stream-json", "--verbose"]
    |> add_option("--model", config[:model])
    |> add_option("--instructions", config[:instructions])
    |> add_permission_mode(config[:permission_mode])
    |> add_option("--mcp-config", mcp_config_path(config))
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

  defp mcp_config_path(%{
         mcp_config_path: path,
         workspace: workspace,
         sandbox_module: AgentYard.Sandboxes.Docker
       })
       when is_binary(path) do
    relative_path = Path.relative_to(path, workspace)
    Path.join("/workspace", relative_path)
  end

  defp mcp_config_path(%{mcp_config_path: path}) when is_binary(path), do: path
  defp mcp_config_path(_config), do: nil

  defp mcp_payload?(servers) do
    Map.has_key?(servers, "mcpServers") or Map.has_key?(servers, :mcpServers)
  end

  defp exclude_from_git(workspace) do
    exclude = Path.join(workspace, ".git/info/exclude")

    if File.exists?(exclude) do
      content = File.read!(exclude)

      if String.contains?(content, ".agentyard/"),
        do: :ok,
        else: File.write(exclude, "\n.agentyard/\n", [:append])
    else
      :ok
    end
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
