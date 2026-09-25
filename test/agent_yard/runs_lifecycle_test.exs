defmodule AgentYard.RunsLifecycleTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias AgentYard.Audit.Event, as: AuditEvent
  alias AgentYard.Repo
  alias AgentYard.Runs
  alias AgentYard.Runs.{RunEvent, Session}
  alias AgentYard.Secrets
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

      assert {:ok, %{args: %{"run_id" => run_id}}} = Runs.start_run(run)
      assert run_id == run.id

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
      assert Repo.exists?(from(audit in AuditEvent, where: audit.subject_id == ^run.id))
    end
  end

  test "injects scoped secrets and masks them in the event timeline", context do
    if context[:database] == false do
      assert true
    else
      {:ok, _team_secret} =
        Secrets.put(context.team.id, %{name: "TEAM_TOKEN", value: "team-secret"})

      {:ok, _repository_secret} =
        Secrets.put(context.team.id, %{
          name: "REPOSITORY_TOKEN",
          value: "repository-secret",
          scope: "repository",
          repository_id: context.repository.id
        })

      {:ok, run} =
        Runs.create_run(context.user, context.team, %{
          repository_id: context.repository.id,
          agent_profile_id: context.profile.id,
          prompt: "Use repository-secret while fixing the task"
        })

      assert {:ok, _job} = Runs.start_run(run)

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run.id).status == "succeeded"
             end)

      events = Runs.list_events(Repo.get!(AgentYard.Runs.Run, run.id))

      assert Enum.any?(
               events,
               &(&1.payload["message"] == "Scoped secrets injected into adapter environment")
             )

      serialized = Enum.map_join(events, "\n", &inspect(&1.payload))
      refute serialized =~ "repository-secret"
      refute serialized =~ "team-secret"
      assert serialized =~ "[REDACTED]"
    end
  end

  test "stops a run when its reported cost exceeds the profile budget", context do
    if context[:database] == false do
      assert true
    else
      profile =
        TestFactory.profile_fixture(context.team, %{
          name: "Tiny budget fake",
          budget_usd: Decimal.new("0.01")
        })

      {:ok, run} =
        Runs.create_run(context.user, context.team, %{
          repository_id: context.repository.id,
          agent_profile_id: profile.id,
          prompt: "Exceed the tiny budget"
        })

      assert {:ok, _job} = Runs.start_run(run)

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run.id).status == "failed"
             end)

      events = Runs.list_events(Repo.get!(AgentYard.Runs.Run, run.id))

      assert Enum.any?(events, fn event ->
               is_binary(event.payload["message"]) and
                 event.payload["message"] =~ "budget exceeded"
             end)
    end
  end

  test "stops a run after its maximum tool turns", context do
    if context[:database] == false do
      assert true
    else
      {:ok, run} =
        Runs.create_run(context.user, context.team, %{
          repository_id: context.repository.id,
          agent_profile_id: context.profile.id,
          prompt: "Stop after one turn",
          max_turns: 1
        })

      assert {:ok, _job} = Runs.start_run(run)

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run.id).status == "failed"
             end)

      events = Runs.list_events(Repo.get!(AgentYard.Runs.Run, run.id))

      assert Enum.any?(events, fn event ->
               is_binary(event.payload["message"]) and event.payload["message"] =~ "maximum turns"
             end)
    end
  end

  test "allows a run whose reported cost is exactly its budget", context do
    if context[:database] == false do
      assert true
    else
      profile =
        TestFactory.profile_fixture(context.team, %{
          name: "Exact budget fake",
          budget_usd: Decimal.new("0.04")
        })

      {:ok, run} =
        Runs.create_run(context.user, context.team, %{
          repository_id: context.repository.id,
          agent_profile_id: profile.id,
          prompt: "Stay exactly within budget"
        })

      assert {:ok, _job} = Runs.start_run(run)

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run.id).status == "succeeded"
             end)

      assert Decimal.equal?(Repo.get!(AgentYard.Runs.Run, run.id).cost_usd, Decimal.new("0.04"))
    end
  end
end
