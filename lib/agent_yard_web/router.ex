defmodule AgentYardWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AgentYardWeb.Layouts, :root})
    plug(AgentYardWeb.UserAuth, :fetch_current_user)
    plug(:protect_from_forgery)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(AgentYardWeb.ApiAuth)
  end

  scope "/", AgentYardWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/login", SessionController, :new)
    post("/login", SessionController, :create)
    get("/login/magic/sent", SessionController, :magic_link_sent)
    post("/login/magic", SessionController, :request_magic_link)
    get("/login/magic/:token", SessionController, :consume_magic_link)
    get("/register", SessionController, :register)
    post("/register", SessionController, :do_register)
    get("/logout", SessionController, :delete)

    live_session :authenticated,
      on_mount: [{AgentYardWeb.UserAuth, :current_user}],
      layout: {AgentYardWeb.Layouts, :app} do
      live("/runs", RunsLive.Index, :index)
      live("/runs/new", RunsLive.New, :new)
      live("/runs/:id", RunsLive.Show, :show)
      live("/repositories", RepositoriesLive.Index, :index)
      live("/profiles", ProfilesLive.Index, :index)
      live("/team/settings", TeamLive.Settings, :settings)
    end
  end

  scope "/api", AgentYardWeb.Api do
    pipe_through(:api)

    get("/openapi.yaml", OpenAPIController, :show)
    get("/repositories", RepositoryController, :index)
    get("/runs", RunController, :index)
    post("/runs", RunController, :create)
    get("/runs/:id", RunController, :show)
    get("/runs/:id/usage", RunController, :usage)
    get("/sessions/:id/usage", RunController, :session_usage)
    post("/runs/:id/followups", RunController, :follow_up)
    post("/runs/:id/cancel", RunController, :cancel)
    get("/runs/:id/events", RunController, :events)
    get("/runs/:id/events/stream", RunController, :stream)
  end

  scope "/webhooks", AgentYardWeb do
    post("/github", WebhookController, :github)
    post("/gitlab", WebhookController, :gitlab)
  end
end
