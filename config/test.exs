import Config

config :agentyard,
  start_repo: false,
  demo_mode: false

config :agentyard, AgentYardWeb.Endpoint,
  server: false,
  secret_key_base: "test-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-0123456789",
  http: [ip: {127, 0, 0, 1}, port: 4002]

config :logger, level: :warning
