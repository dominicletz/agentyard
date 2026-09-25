import Config

database_url =
  System.get_env("DATABASE_URL") ||
    "ecto://#{System.get_env("POSTGRES_USER", "postgres")}:#{System.get_env("POSTGRES_PASSWORD", "postgres")}@#{System.get_env("POSTGRES_HOST", "db")}/#{System.get_env("POSTGRES_DB", "agentyard")}"

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is required in production"

  config :agentyard, AgentYardWeb.Endpoint,
    url: [host: System.get_env("PHX_HOST", "localhost"), port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000"))
    ],
    secret_key_base: secret_key_base,
    server: true

  config :agentyard, AgentYard.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("DATABASE_SSL", "false") == "true"

  config :agentyard,
    secret_key: System.get_env("AGENTYARD_SECRET_KEY") || secret_key_base,
    demo_mode: System.get_env("DEMO_MODE", "false") == "true"
end
