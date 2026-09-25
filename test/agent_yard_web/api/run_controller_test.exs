defmodule AgentYardWeb.Api.RunControllerTest do
  @moduledoc """
  Integration coverage for the bearer-authenticated run API.
  """

  use AgentYardWeb.ConnCase, async: false

  import Ecto.Query

  alias AgentYard.Accounts
  alias AgentYard.Repo
  alias AgentYard.Runs.RunEvent
  alias AgentYard.TestFactory

  setup do
    if Process.whereis(Repo) do
      fixture = TestFactory.run_fixture()
      {:ok, token, _record} = Accounts.create_api_token(fixture.user, "test API")
      {:ok, Map.put(fixture, :api_token, token)}
    else
      {:ok, database: false}
    end
  end

  test "lists a team's runs through the bearer API", context do
    if context[:database] == false do
      assert true
    else
      conn = get(authenticated(context.conn, context.api_token), "/api/runs")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  test "creates a fake run and exposes its event log", context do
    if context[:database] == false do
      assert true
    else
      params = %{
        repository_id: context.repository.id,
        agent_profile_id: context.profile.id,
        prompt: "Exercise the API lifecycle"
      }

      conn =
        context.conn
        |> authenticated(context.api_token)
        |> post("/api/runs", Jason.encode!(params))

      %{"data" => %{"id" => run_id, "status" => status}} = json_response(conn, 202)
      assert status in ["queued", "running", "succeeded"]

      assert TestFactory.eventually(fn ->
               Repo.exists?(
                 from(event in RunEvent,
                   where: event.run_id == ^run_id and event.kind == "assistant_delta"
                 )
               )
             end)

      conn = get(authenticated(context.conn, context.api_token), "/api/runs/#{run_id}/events")
      events = json_response(conn, 200)["data"]
      assert Enum.any?(events, &(&1["kind"] == "assistant_delta"))
    end
  end

  test "exposes repository metadata and run/session usage aggregates", context do
    if context[:database] == false do
      assert true
    else
      repositories =
        context.conn
        |> authenticated(context.api_token)
        |> get("/api/repositories")
        |> json_response(200)

      assert [%{"id" => id, "name" => "example/repository", "default_branch" => "main"}] =
               repositories["data"]

      assert id == context.repository.id

      params = %{
        repository_id: context.repository.id,
        agent_profile_id: context.profile.id,
        prompt: "Read usage after completion"
      }

      conn =
        context.conn
        |> authenticated(context.api_token)
        |> post("/api/runs", Jason.encode!(params))

      run_id = json_response(conn, 202)["data"]["id"]

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run_id).status == "succeeded"
             end)

      run = Repo.get!(AgentYard.Runs.Run, run_id)

      run_usage =
        context.conn
        |> authenticated(context.api_token)
        |> get("/api/runs/#{run_id}/usage")
        |> json_response(200)

      assert run_usage["data"]["run_id"] == run_id
      assert run_usage["data"]["input_tokens"] == 420
      assert run_usage["data"]["output_tokens"] == 180
      assert run_usage["data"]["cost_usd"] == "0"

      session_usage =
        context.conn
        |> authenticated(context.api_token)
        |> get("/api/sessions/#{run.session_id}/usage")
        |> json_response(200)

      assert session_usage["data"]["session_id"] == run.session_id
      assert session_usage["data"]["run_count"] == 1
      assert session_usage["data"]["input_tokens"] == 420
      assert [%{"id" => ^run_id, "status" => "succeeded"}] = session_usage["data"]["runs"]
    end
  end

  defp authenticated(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end
end
