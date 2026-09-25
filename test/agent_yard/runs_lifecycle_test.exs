defmodule AgentYard.RunsLifecycleTest do
  use ExUnit.Case, async: false

  alias AgentYard.Repo
  alias AgentYard.Runs
  alias AgentYard.Runs.{RunEvent, Session}
  alias AgentYard.TestFactory

  setup do
    if Process.whereis(Repo) do
      {:ok, TestFactory.run_fixture()}
    else
      {:ok, database: false}
    end
  end

  test "fake adapter persists a complete run event timeline", context do
    if context[:database] == false do
      assert true
    else
      {:ok, run} =
        Runs.create_run(context.user, context.team, %{
          repository_id: context.repository.id,
          agent_profile_id: context.profile.id,
          prompt: "Exercise the fake lifecycle"
        })

      assert {:ok, _pid} = Runs.start_run(run)

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run.id).status == "succeeded"
             end)

      events = Runs.list_events(Repo.get!(AgentYard.Runs.Run, run.id))

      assert Enum.count(
               events,
               &(&1.kind == "status" and &1.payload["message"] == "Creating an isolated workspace")
             ) == 1

      assert Enum.any?(events, &(&1.kind == "assistant_delta"))
      assert Enum.any?(events, &(&1.kind == "done"))
      assert Enum.all?(events, &match?(%RunEvent{}, &1))
      assert Repo.get!(Session, run.session_id).status == "active"
    end
  end
end
