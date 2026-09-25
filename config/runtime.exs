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

  smtp_relay =
    System.get_env("SMTP_RELAY") ||
      raise "SMTP_RELAY is required in production"

  smtp_username =
    System.get_env("SMTP_USERNAME") ||
      raise "SMTP_USERNAME is required in production"

  smtp_password =
    System.get_env("SMTP_PASSWORD") ||
      raise "SMTP_PASSWORD is required in production"

  mailer_from =
    System.get_env("MAILER_FROM") ||
      raise "MAILER_FROM is required in production"

  config :agentyard,
    mailer_from: {System.get_env("MAILER_FROM_NAME", "AgentYard"), mailer_from}

  config :agentyard, AgentYard.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_relay,
    username: smtp_username,
    password: smtp_password,
    port: System.get_env("SMTP_PORT", "587"),
    tls: System.get_env("SMTP_TLS", "always"),
    auth: System.get_env("SMTP_AUTH", "always"),
    ssl: System.get_env("SMTP_SSL", "false"),
    retries: 2
end
