defmodule AgentYardWeb.PageController do
  use AgentYardWeb, :controller

  def home(%{assigns: %{current_user: %{} = _user}} = conn), do: redirect(conn, to: "/runs")
  def home(conn), do: redirect(conn, to: "/login")
end
