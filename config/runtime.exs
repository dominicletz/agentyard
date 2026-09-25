import Config

database_url =
  case System.get_env("DATABASE_URL") do
    nil ->
      username = URI.encode_www_form(System.get_env("POSTGRES_USER", "postgres"))
      password = URI.encode_www_form(System.get_env("POSTGRES_PASSWORD", "postgres"))
      host = System.get_env("POSTGRES_HOST", "db")
      port = System.get_env("POSTGRES_PORT", "5432")
      database = System.get_env("POSTGRES_DB", "agentyard")

      "ecto://#{username}:#{password}@#{host}:#{port}/#{database}"

    database_url ->
      database_url
  end

if config_env() == :prod do
  secret_key_base = System.fetch_env!("SECRET_KEY_BASE")
  secret_key = System.fetch_env!("AGENTYARD_SECRET_KEY")
  host = System.get_env("PHX_HOST", "localhost")
  port = String.to_integer(System.get_env("PORT", "4000"))
  scheme = System.get_env("PHX_SCHEME", "https")

  url_port =
    System.get_env(
      "PHX_URL_PORT",
      if(scheme == "https", do: "443", else: Integer.to_string(port))
    )
    |> String.to_integer()

  config :agentyard, AgentYardWeb.Endpoint,
    url: [host: host, port: url_port, scheme: scheme],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: System.get_env("PHX_SERVER", "true") == "true"

  config :agentyard, AgentYard.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("DATABASE_SSL", "false") == "true"

  config :agentyard,
    secret_key: secret_key,
    demo_mode: System.get_env("DEMO_MODE", "false") == "true"
end
