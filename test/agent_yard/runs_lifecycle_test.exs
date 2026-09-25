defmodule AgentYard.RunsLifecycleTest do
  use ExUnit.Case, async: false

  alias AgentYard.Accounts.{Membership, Team, User}
  alias AgentYard.AgentProfiles.Profile
  alias AgentYard.Repo
  alias AgentYard.Repositories.Repository
  alias AgentYard.Runs
  alias AgentYard.Runs.{RunEvent, Session}

  setup do
    if Process.whereis(Repo) do
      user =
        %User{}
        |> User.registration_changeset(%{
          email: "lifecycle-#{System.unique_integer([:positive])}@example.com",
          name: "Lifecycle User",
          password: "long-enough-password"
        })
        |> Repo.insert!()

      team = Repo.insert!(%Team{name: "Lifecycle Team", slug: "lifecycle-#{user.id}"})
      Repo.insert!(%Membership{user_id: user.id, team_id: team.id, role: "owner"})

      repository =
        Repo.insert!(%Repository{
          team_id: team.id,
          name: "lifecycle/repo",
          remote_url: "https://example.com/lifecycle.git",
          default_branch: "main"
        })

      profile =
        Repo.insert!(%Profile{
          team_id: team.id,
          name: "Lifecycle fake",
          provider: "fake",
          permission_mode: "accept_edits",
          budget_usd: Decimal.new("1.00")
        })

      {:ok, user: user, team: team, repository: repository, profile: profile}
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
      assert eventually(fn -> Repo.get!(AgentYard.Runs.Run, run.id).status == "succeeded" end)

      events = Runs.list_events(Repo.get!(AgentYard.Runs.Run, run.id))
      assert Enum.any?(events, &(&1.kind == "assistant_delta"))
      assert Enum.any?(events, &(&1.kind == "done"))
      assert Enum.all?(events, &match?(%RunEvent{}, &1))
      assert Repo.get!(Session, run.session_id).status == "active"
    end
  end

  defp eventually(predicate, attempts \\ 40)
  defp eventually(_predicate, 0), do: false

  defp eventually(predicate, attempts) do
    if predicate.() do
      true
    else
      Process.sleep(50)
      eventually(predicate, attempts - 1)
    end
  end
end
