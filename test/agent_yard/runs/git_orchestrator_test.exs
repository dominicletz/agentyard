defmodule AgentYard.Runs.GitOrchestratorTest do
  use ExUnit.Case, async: true

  alias AgentYard.Git.Command
  alias AgentYard.Repositories.Repository
  alias AgentYard.Runs.{GitOrchestrator, Run, Session}

  defmodule StubProvider do
    def commit_and_push(config, _workspace, _branch, _message) do
      send(config.test_pid, :commit_and_push_called)
      :ok
    end

    def open_change(config, _branch, _title, _body) do
      send(config.test_pid, :open_change_called)
      {:ok, %{url: "https://github.example.test/pulls/42"}}
    end
  end

  test "publishes changed workspace through the configured forge provider" do
    workspace =
      Path.join(
        System.tmp_dir!(),
        "agentyard-git-orchestrator-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(workspace) end)

    assert {:ok, _} = Command.run(["init", "-b", "main", workspace])
    assert {:ok, _} = Command.run(["-C", workspace, "config", "user.name", "AgentYard"])
    assert {:ok, _} = Command.run(["-C", workspace, "config", "user.email", "agent@example.test"])
    assert :ok = File.write(Path.join(workspace, "change.txt"), "changed\n")

    run = %Run{
      id: Ecto.UUID.generate(),
      prompt: "Change the example",
      status: "running",
      adapter: "fake",
      auto_pr: true,
      branch_name: "agent/example",
      session: %Session{
        title: "Change the example",
        repository: %Repository{
          forge: "github",
          remote_url: "https://github.example.test/team/repo.git"
        }
      }
    }

    config = %{
      forge_token: "token",
      git_prepared: true,
      git_provider: StubProvider,
      workspace: workspace,
      forge_config: %{test_pid: self()}
    }

    assert {:ok, %{url: "https://github.example.test/pulls/42"}, _events} =
             GitOrchestrator.finalize(run, config)

    assert_received :commit_and_push_called
    assert_received :open_change_called
  end

  test "captures tracked and untracked workspace changes as a real patch" do
    workspace =
      Path.join(
        System.tmp_dir!(),
        "agentyard-git-diff-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(workspace) end)

    assert {:ok, _} = Command.run(["init", "-b", "main", workspace])
    assert {:ok, _} = Command.run(["-C", workspace, "config", "user.name", "AgentYard"])
    assert {:ok, _} = Command.run(["-C", workspace, "config", "user.email", "agent@example.test"])
    assert :ok = File.write(Path.join(workspace, "tracked.txt"), "before\n")
    assert {:ok, _} = Command.run(["-C", workspace, "add", "tracked.txt"])
    assert {:ok, _} = Command.run(["-C", workspace, "commit", "-m", "seed"])
    assert :ok = File.write(Path.join(workspace, "tracked.txt"), "after\n")
    assert :ok = File.write(Path.join(workspace, "new.txt"), "new file\n")

    assert {:ok, diff} = GitOrchestrator.workspace_diff(%{workspace: workspace})
    assert diff =~ "tracked.txt"
    assert diff =~ "-before"
    assert diff =~ "+after"
    assert diff =~ "new.txt"
    assert diff =~ "+new file"
  end

  test "skips forge publication with an explicit event when no token is available" do
    run = %Run{
      id: Ecto.UUID.generate(),
      prompt: "No forge credentials",
      auto_pr: true,
      session: %Session{repository: %Repository{forge: "gitlab"}}
    }

    assert {:ok, nil, [%AgentYard.Agents.Event{type: "status", message: message}]} =
             GitOrchestrator.finalize(run, %{forge_token: nil})

    assert message =~ "no GITLAB_TOKEN configured"
  end
end
