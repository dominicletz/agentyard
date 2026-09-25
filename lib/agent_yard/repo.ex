defmodule AgentYard.Repo do
  use Ecto.Repo,
    otp_app: :agentyard,
    adapter: Ecto.Adapters.Postgres
end
