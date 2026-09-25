import Config

config :agentyard, AgentYardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "dev-only-secret-key-base-change-for-production-use-a-real-secret-0123456789"
    ),
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :agentyard, AgentYard.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "agentyard_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :agentyard, AgentYardWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/agentyard_web/(live|components)/.*(ex|heex)$",
      ~r"lib/agentyard_web/templates/.*(eex)$"
    ]
  ]
