defmodule AgentYard.Runs.ResourceCleanupTest do
  use ExUnit.Case, async: true

  defmodule SandboxStub do
    def cleanup(config) do
      send(config.cleanup_pid, :sandbox_cleanup_called)
      :ok
    end
  end

  alias AgentYard.Runs.ResourceCleanup

  test "invokes the sandbox hook and removes the managed workspace" do
    workspace =
      Path.join(
        System.tmp_dir!(),
        "agentyard-cleanup-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(workspace)
    File.write!(Path.join(workspace, "artifact.txt"), "temporary")
    on_exit(fn -> File.rm_rf!(workspace) end)

    config = %{
      workspace: workspace,
      workspace_managed?: true,
      cleanup_pid: self()
    }

    assert :ok = ResourceCleanup.cleanup(SandboxStub, config)
    assert_received :sandbox_cleanup_called
    refute File.exists?(workspace)
  end

  test "does not remove caller-owned workspaces" do
    workspace =
      Path.join(
        System.tmp_dir!(),
        "agentyard-owned-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(workspace)
    on_exit(fn -> File.rm_rf!(workspace) end)

    assert :ok = ResourceCleanup.cleanup(nil, %{workspace: workspace})
    assert File.dir?(workspace)
  end
end
