defmodule AgentYardWeb.UserAuth do
  import Plug.Conn
  import Phoenix.LiveView

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
    |> assign(:current_user, user)
    |> assign(:team, user && Accounts.team_for_user(user))
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
      |> assign(:current_user, user)
      |> assign(:team, user && Accounts.team_for_user(user))
      |> assign(:active_nav, nil)

    if user || Application.get_env(:agentyard, :demo_mode, false) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end

  def log_in_user(conn, user) do
    conn
    |> configure_session(renew: true)
    |> put_session(:user_id, user.id)
    |> redirect(to: "/runs")
  end

  def log_out_user(conn) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/login")
  end

  defp demo_user,
    do: if(Application.get_env(:agentyard, :demo_mode, false), do: Accounts.demo_user())
end
