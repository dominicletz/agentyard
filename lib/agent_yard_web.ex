defmodule AgentYardWeb do
  @moduledoc """
  Entry points and shared imports for the AgentYard web layer.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: AgentYardWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: AgentYardWeb.Gettext
      alias AgentYardWeb.Router.Helpers, as: Routes
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {AgentYardWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.HTML
      import AgentYardWeb.CoreComponents
      use Gettext, backend: AgentYardWeb.Gettext
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  defp html_helpers do
    quote do
      unquote(html())
      import Phoenix.LiveView.Helpers
      import Phoenix.LiveView
      alias AgentYardWeb.Router.Helpers, as: Routes
    end
  end

  defp verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AgentYardWeb.Endpoint,
        router: AgentYardWeb.Router,
        statics: AgentYardWeb.static_paths()
    end
  end

  def static_paths, do: ~w(css js images favicon.ico robots.txt openapi.yaml)

  defmacro __using__(which) when which in [:controller, :live_view, :html] do
    apply(__MODULE__, which, [])
  end
end
