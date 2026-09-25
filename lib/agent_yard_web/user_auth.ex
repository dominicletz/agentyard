defmodule AgentYardWeb.UserAuth do
  @moduledoc """
  Browser and LiveView authentication helpers for the current user.
  """

  import Plug.Conn

  alias AgentYard.Accounts

  def init(action), do: action

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])

  def fetch_current_user(conn, _opts) do
    user =
      conn
      |> get_session(:user_id)
      |> case do
        nil -> demo_user()
        id -> Accounts.get_user(id) || demo_user()
      end

    conn
    |> Plug.Conn.assign(:current_user, user)
    |> Plug.Conn.assign(:team, user && Accounts.team_for_user(user))
  end

  def require_authenticated_user(%Plug.Conn{assigns: %{current_user: %{} = user}} = conn, _opts)
      when not is_nil(user),
      do: conn

  def require_authenticated_user(conn, _opts) do
    conn
    |> Phoenix.Controller.redirect(to: "/login")
    |> halt()
  end

  def on_mount(:current_user, _params, session, socket) do
    user =
      case session["user_id"] do
        nil -> demo_user()
        id -> Accounts.get_user(id) || demo_user()
      end

    socket =
      socket
      |> Phoenix.Component.assign(:current_user, user)
      |> Phoenix.Component.assign(:team, user && Accounts.team_for_user(user))
      |> Phoenix.Component.assign(:active_nav, nil)

    if user || Application.get_env(:agentyard, :demo_mode, false) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
    end
  end

  def log_in_user(conn, user) do
    conn
    |> configure_session(renew: true)
    |> put_session(:user_id, user.id)
    |> Phoenix.Controller.redirect(to: "/runs")
  end

  def log_out_user(conn) do
    conn
    |> configure_session(drop: true)
    |> Phoenix.Controller.redirect(to: "/login")
  end

  defp demo_user,
    do: if(Application.get_env(:agentyard, :demo_mode, false), do: Accounts.demo_user())
end
