import Config

config :agentyard,
  ecto_repos: [AgentYard.Repo],
  generators: [timestamp_type: :utc_datetime_usec],
  start_repo: true,
  demo_mode: true,
  secret_key: System.get_env("AGENTYARD_SECRET_KEY") || "development-secret-change-me"

config :agentyard, AgentYardWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AgentYardWeb.ErrorHTML, json: AgentYardWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AgentYard.PubSub,
  live_view: [signing_salt: "agentyard-live-view"]

config :agentyard, AgentYard.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec],
  pool_size: 10

config :agentyard, Oban,
  repo: AgentYard.Repo,
  queues: [runs: 10],
  plugins: []

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.17.19",
  agentyard: [
    args: ~w(assets/js/app.js --bundle --target=es2017 --outdir=priv/static/js),
    cd: Path.expand("..", __DIR__)
  ]

config :logger, :console,
  format: "$time [$level] $metadata$message\n",
  metadata: [:request_id, :run_id]

if config_env() == :dev do
  import_config "dev.exs"
end

if config_env() == :test do
  import_config "test.exs"
end
