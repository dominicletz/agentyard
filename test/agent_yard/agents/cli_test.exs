defmodule AgentYard.Agents.CLITest do
  use ExUnit.Case, async: true

  alias AgentYard.Agents.CLI

  test "materializes MCP servers and passes the config to Claude and Cursor" do
    workspace =
      Path.join(
        System.tmp_dir!(),
        "agentyard-mcp-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(workspace) end)
    exclude = Path.join(workspace, ".git/info/exclude")
    File.mkdir_p!(Path.dirname(exclude))
    File.write!(exclude, "# git ls-files --others --exclude-from=.git/info/exclude\n")

    config = %{
      workspace: workspace,
      prompt: "Inspect the app",
      mcp_servers: %{
        "docs" => %{"command" => "npx", "args" => ["-y", "mcp-docs"]}
      }
    }

    assert {:ok, prepared} = CLI.prepare(config)
    path = prepared.mcp_config_path
    assert File.exists?(path)
    assert %{"mcpServers" => %{"docs" => _}} = Jason.decode!(File.read!(path))
    assert File.read!(exclude) =~ ".agentyard/"

    for provider <- [:claude_code, :cursor_cli] do
      args = CLI.command_args(prepared, provider)
      index = Enum.find_index(args, &(&1 == "--mcp-config"))
      assert is_integer(index)
      assert Enum.at(args, index + 1) == path
    end
  end

  test "uses the container path for MCP config in Docker" do
    config = %{
      workspace: "/tmp/agentyard-run",
      mcp_config_path: "/tmp/agentyard-run/.agentyard/mcp.json",
      sandbox_module: AgentYard.Sandboxes.Docker,
      prompt: "Inspect"
    }

    args = CLI.command_args(config, :claude_code)
    index = Enum.find_index(args, &(&1 == "--mcp-config"))
    assert Enum.at(args, index + 1) == "/workspace/.agentyard/mcp.json"
  end
end
