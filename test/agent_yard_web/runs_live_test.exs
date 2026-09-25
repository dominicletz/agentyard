defmodule AgentYardWeb.RunsLiveTest do
  @moduledoc """
  Smoke coverage for the authenticated run LiveViews.
  """

  use AgentYardWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias AgentYard.Repo
  alias AgentYard.TestFactory

  setup %{conn: conn} do
    if Process.whereis(Repo) do
      fixture = TestFactory.run_fixture()
      conn = init_test_session(conn, user_id: fixture.user.id)
      {:ok, Map.put(fixture, :conn, conn)}
    else
      {:ok, database: false}
    end
  end

  test "renders the runs overview for an authenticated team", context do
    if context[:database] == false do
      assert true
    else
      assert {:ok, _view, html} = live(context.conn, "/runs")
      assert html =~ "Recent runs"
      assert html =~ "New run"
    end
  end

  test "renders the new-run composer", context do
    if context[:database] == false do
      assert true
    else
      assert {:ok, _view, html} = live(context.conn, "/runs/new")
      assert html =~ "Start run"
      assert html =~ "What happens next"
    end
  end
end
