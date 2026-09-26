defmodule AgentYardWeb.SessionControllerTest do
  use AgentYardWeb.ConnCase, async: true

  test "login page renders without a database-backed session", %{conn: conn} do
    conn = get(conn, "/login")

    assert html_response(conn, 200) =~ "Sign in to AgentYard"
    assert html_response(conn, 200) =~ "Email me a magic link"
    assert html_response(conn, 200) =~ ~s(action="/login/magic")
    assert html_response(conn, 200) =~ "csrf_token"
    assert html_response(conn, 200) =~ "<!DOCTYPE html>"
    assert html_response(conn, 200) =~ ~s(<link rel="stylesheet" href="/css/app.css")
    assert html_response(conn, 200) =~ ~s(<link rel="stylesheet" href="/css/polish.css")
    assert html_response(conn, 200) =~ ~s(src="/images/agentyard-mark.svg")
  end

  test "registration and magic-link pages use the root layout", %{conn: conn} do
    register = conn |> get("/register") |> html_response(200)
    magic_link_sent = build_conn() |> get("/login/magic/sent") |> html_response(200)

    for html <- [register, magic_link_sent] do
      assert html =~ "<!DOCTYPE html>"
      assert html =~ ~s(<link rel="stylesheet" href="/css/app.css")
      assert html =~ ~s(<link rel="stylesheet" href="/css/polish.css")
    end

    assert register =~ "Create your AgentYard account"
    assert magic_link_sent =~ "Check your email for a one-time sign-in link."
  end
end
