defmodule AgentYardWeb.ConnCase do
  @moduledoc """
  Shared connection setup for controller and API tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint AgentYardWeb.Endpoint
      import Plug.Conn
      import Phoenix.ConnTest
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
