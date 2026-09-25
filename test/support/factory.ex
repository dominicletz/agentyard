defmodule AgentYard.TestFactory do
  @moduledoc """
  Small database fixtures shared by integration and web tests.
  """

  alias AgentYard.Accounts.{Membership, Team, User}
  alias AgentYard.AgentProfiles.Profile
  alias AgentYard.Repo
  alias AgentYard.Repositories.Repository

  def run_fixture(opts \\ %{}) do
    %{user: user, team: team} = user_team_fixture(opts)

    repository =
      repository_fixture(team, %{
        name: Map.get(opts, :repository_name, "example/repository")
      })

    profile =
      profile_fixture(team, %{
        name: Map.get(opts, :profile_name, "Test fake agent")
      })

    %{user: user, team: team, repository: repository, profile: profile}
  end

  def user_team_fixture(opts \\ %{}) do
    suffix = Ecto.UUID.generate() |> String.replace("-", "")

    user =
      %User{}
      |> User.registration_changeset(%{
        email: Map.get(opts, :email, "test-#{suffix}@example.com"),
        name: Map.get(opts, :name, "Test User"),
        password: Map.get(opts, :password, "long-enough-password")
      })
      |> Repo.insert!()

    team =
      Repo.insert!(%Team{
        name: Map.get(opts, :team_name, "Test Team"),
        slug: "test-team-#{suffix}"
      })

    Repo.insert!(%Membership{user_id: user.id, team_id: team.id, role: "owner"})
    %{user: user, team: team}
  end

  def repository_fixture(team, attrs \\ %{}) do
    base = %{
      team_id: team.id,
      name: "example/repository",
      remote_url: "https://example.com/example/repository.git",
      default_branch: "main"
    }

    base
    |> Map.merge(attrs)
    |> then(&Repository.changeset(%Repository{}, &1))
    |> Repo.insert!()
  end

  def profile_fixture(team, attrs \\ %{}) do
    base = %{
      team_id: team.id,
      name: "Test fake agent",
      provider: "fake",
      permission_mode: "accept_edits",
      budget_usd: Decimal.new("1.00")
    }

    base
    |> Map.merge(attrs)
    |> then(&Profile.changeset(%Profile{}, &1))
    |> Repo.insert!()
  end

  def eventually(predicate, attempts \\ 40)
  def eventually(_predicate, 0), do: false

  def eventually(predicate, attempts) do
    if predicate.() do
      true
    else
      Process.sleep(50)
      eventually(predicate, attempts - 1)
    end
  end
end
