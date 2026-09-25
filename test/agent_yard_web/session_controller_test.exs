defmodule AgentYardWeb.SessionControllerTest do
  use AgentYardWeb.ConnCase, async: true

  test "login page renders without a database-backed session", %{conn: conn} do
    conn = get(conn, "/login")

    assert html_response(conn, 200) =~ "Sign in to AgentYard"
    assert html_response(conn, 200) =~ "Email me a magic link"
    assert html_response(conn, 200) =~ ~s(action="/login/magic")
    assert html_response(conn, 200) =~ "csrf_token"
  end
end
