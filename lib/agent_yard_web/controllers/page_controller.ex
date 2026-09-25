defmodule AgentYardWeb.PageController do
  use AgentYardWeb, :controller

  def home(%{assigns: %{current_user: %{} = _user}} = conn, _params),
    do: redirect(conn, to: "/runs")

  def home(conn, _params), do: redirect(conn, to: "/login")
end
