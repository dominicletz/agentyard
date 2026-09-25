defmodule AgentYardWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :agentyard

  @session_options [
    store: :cookie,
    key: "_agentyard_key",
    signing_salt: "agentyard-session",
    same_site: "Lax"
  ]

  plug(Plug.Static,
    at: "/",
    from: :agentyard,
    gzip: false,
    only: ~w(css js images favicon.ico robots.txt openapi.yaml)
  )

  socket("/live", Phoenix.LiveView.Socket)

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    body_reader: {AgentYardWeb.RawBodyReader, :read_body, []}
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(AgentYardWeb.Router)
end
