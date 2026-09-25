defmodule AgentYardWeb.ApiAuth do
  @moduledoc """
  Plug that authenticates API requests with personal bearer tokens.
  """

  import Plug.Conn
  alias AgentYard.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Accounts.get_user_by_api_token(token) do
          nil ->
            unauthorized(conn)

          user ->
            conn |> assign(:current_user, user) |> assign(:team, Accounts.team_for_user(user))
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
    |> halt()
  end
end
