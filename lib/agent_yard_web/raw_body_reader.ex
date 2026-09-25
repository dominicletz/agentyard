defmodule AgentYardWeb.RawBodyReader do
  @moduledoc false

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, Plug.Conn.put_private(conn, :agentyard_raw_body, body)}

      {:more, body, conn} ->
        read_more(conn, opts, body)
    end
  end

  defp read_more(conn, opts, body) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, last, conn} ->
        full_body = body <> last
        {:ok, full_body, Plug.Conn.put_private(conn, :agentyard_raw_body, full_body)}

      {:more, more, conn} ->
        read_more(conn, opts, body <> more)
    end
  end
end
