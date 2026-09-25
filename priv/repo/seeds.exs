import Ecto.Query

alias AgentYard.Accounts
alias AgentYard.AgentProfiles.Profile
alias AgentYard.Repositories.Repository
alias AgentYard.Repo
alias AgentYard.Runs

user =
  case Accounts.get_user_by_email("demo@agentyard.local") do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          email: "demo@agentyard.local",
          name: "Demo User",
          password: "demo-password"
        })

      user

    user ->
      user
  end

team =
  case Accounts.team_for_user(user) do
    nil ->
      {:ok, team} = Accounts.create_team_for_user(user, %{name: "Acme Engineering", slug: "acme-engineering"})
      team

    team ->
      team
  end

repository =
  Repo.get_by(Repository, team_id: team.id, name: "acme/payments-api") ||
    Repo.insert!(%Repository{
      team_id: team.id,
      name: "acme/payments-api",
      forge: "github",
      remote_url: "https://github.com/example/payments-api.git",
      default_branch: "main",
      description: "Example repository used by the fake adapter demo."
    })

profile =
  Repo.get_by(Profile, team_id: team.id, name: "Fake demo agent") ||
    Repo.insert!(%Profile{
      team_id: team.id,
      name: "Fake demo agent",
      provider: "fake",
      model: "scripted",
      instructions: "Keep the demo deterministic and explain each step.",
      permission_mode: "accept_edits",
      budget_usd: Decimal.new("5.00")
    })

unless Repo.exists?(from r in AgentYard.Runs.Run, where: r.team_id == ^team.id) do
  {:ok, run} =
    Runs.create_run(user, team, %{
      repository_id: repository.id,
      agent_profile_id: profile.id,
      prompt: "Add idempotency keys to the checkout endpoint.",
      base_branch: "main",
      trigger: "ui"
    })

  {:ok, _pid} = Runs.start_run(run)
end

unless Repo.exists?(from t in AgentYard.Accounts.ApiToken, where: t.user_id == ^user.id) do
  {:ok, token, _record} = Accounts.create_api_token(user, "demo CLI")
  IO.puts("AgentYard demo API token: #{token}")
end

IO.puts("AgentYard demo ready: demo@agentyard.local / demo-password")
