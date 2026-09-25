import Config

config :agentyard,
  start_repo: not is_nil(System.get_env("DATABASE_URL")),
  demo_mode: false

config :agentyard, AgentYard.Mailer, adapter: Swoosh.Adapters.Test

if database_url = System.get_env("DATABASE_URL") do
  config :agentyard, AgentYard.Repo,
    url: database_url,
    pool_size: 5
end

config :agentyard, AgentYardWeb.Endpoint,
  server: false,
  secret_key_base: "test-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-0123456789",
  http: [ip: {127, 0, 0, 1}, port: 4002]

config :logger, level: :warning
