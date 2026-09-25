defmodule AgentYardWeb.Api.RunController do
  use AgentYardWeb, :controller

  alias AgentYard.Runs

  def index(%{assigns: %{team: team}} = conn, params) do
    runs = Runs.list_runs(team, params)
    json(conn, %{data: Enum.map(runs, &run_json/1)})
  end

  def create(%{assigns: %{current_user: user, team: team}} = conn, params) do
    with {:ok, run} <- Runs.create_run(user, team, params),
         {:ok, _pid} <- Runs.start_run(run) do
      run = Runs.get_run!(run.id, team)

      conn
      |> put_status(:accepted)
      |> json(%{data: run_json(run)})
    else
      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def show(%{assigns: %{team: team}} = conn, %{"id" => id}) do
    run = Runs.get_run!(id, team)
    json(conn, %{data: run_json(run)})
  end

  def usage(%{assigns: %{team: team}} = conn, %{"id" => id}) do
    run = Runs.get_run!(id, team)

    json(conn, %{
      data: %{
        run_id: run.id,
        session_id: run.session_id,
        input_tokens: run.input_tokens || 0,
        output_tokens: run.output_tokens || 0,
        cache_tokens: run.cache_tokens || 0,
        cost_usd: decimal(run.cost_usd),
        budget_usd: decimal(run.session.agent_profile.budget_usd)
      }
    })
  end

  def session_usage(%{assigns: %{team: team}} = conn, %{"id" => id}) do
    session = Runs.get_session!(id, team)
    usage = Runs.session_usage(session)

    json(conn, %{
      data: %{
        session_id: usage.session_id,
        run_count: usage.run_count,
        input_tokens: usage.input_tokens,
        output_tokens: usage.output_tokens,
        cache_tokens: usage.cache_tokens,
        cost_usd: decimal(usage.cost_usd),
        budget_usd: decimal(usage.budget_usd),
        runs:
          Enum.map(usage.runs, fn run ->
            Map.update!(run, :cost_usd, &decimal/1)
          end)
      }
    })
  end

  def follow_up(%{assigns: %{current_user: user, team: team}} = conn, %{"id" => id} = params) do
    run = Runs.get_run!(id, team)

    with {:ok, new_run} <- Runs.follow_up(run, user, params["prompt"]),
         {:ok, _pid} <- Runs.start_run(new_run) do
      new_run = Runs.get_run!(new_run.id, team)
      conn |> put_status(:accepted) |> json(%{data: run_json(new_run)})
    else
      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def cancel(%{assigns: %{current_user: user, team: team}} = conn, %{"id" => id}) do
    run = Runs.get_run!(id, team)

    case Runs.cancel(run, user) do
      {:ok, run} ->
        json(conn, %{data: run_json(run)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def events(%{assigns: %{team: team}} = conn, %{"id" => id} = params) do
    run = Runs.get_run!(id, team)
    after_sequence = parse_integer(params["after"])
    json(conn, %{data: Enum.map(Runs.list_events(run, after_sequence), &event_json/1)})
  end

  def stream(%{assigns: %{team: team}} = conn, %{"id" => id} = params) do
    run = Runs.get_run!(id, team)

    last_event_id =
      parse_integer(get_req_header(conn, "last-event-id") |> List.first() || params["after"])

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> send_chunked(200)

    case send_events(conn, Runs.list_events(run, last_event_id)) do
      {:ok, conn} ->
        Phoenix.PubSub.subscribe(AgentYard.PubSub, Runs.topic(run.id))
        stream_loop(conn, run.id)

      {:error, :closed} ->
        conn
    end
  end

  defp stream_loop(conn, run_id) do
    receive do
      {:run_event, ^run_id, event} ->
        case Plug.Conn.chunk(
               conn,
               "id: #{event.sequence}\ndata: #{Jason.encode!(event_json(event))}\n\n"
             ) do
          {:ok, conn} -> stream_loop(conn, run_id)
          {:error, :closed} -> conn
        end
    after
      30_000 -> conn
    end
  end

  defp send_events(conn, events) do
    Enum.reduce_while(events, {:ok, conn}, fn event, {:ok, conn} ->
      case Plug.Conn.chunk(
             conn,
             "id: #{event.sequence}\ndata: #{Jason.encode!(event_json(event))}\n\n"
           ) do
        {:ok, conn} -> {:cont, {:ok, conn}}
        {:error, :closed} -> {:halt, {:error, :closed}}
      end
    end)
  end

  defp run_json(run) do
    %{
      id: run.id,
      prompt: run.prompt,
      status: run.status,
      trigger: run.trigger,
      base_branch: run.base_branch,
      branch_name: run.branch_name,
      adapter: run.adapter,
      auto_pr: run.auto_pr,
      environment: run.environment,
      issue_url: run.issue_url,
      timeout_seconds: run.timeout_seconds,
      max_turns: run.max_turns,
      usage: %{
        input_tokens: run.input_tokens || 0,
        output_tokens: run.output_tokens || 0,
        cache_tokens: run.cache_tokens || 0,
        cost_usd: decimal(run.cost_usd)
      },
      pr_url: run.pr_url,
      merge_request_url: run.merge_request_url,
      error: run.error,
      session_id: run.session_id,
      repository_id: run.session.repository_id,
      inserted_at: run.inserted_at
    }
  end

  defp event_json(event) do
    %{
      id: event.id,
      sequence: event.sequence,
      kind: event.kind,
      payload: event.payload,
      inserted_at: event.inserted_at
    }
  end

  defp decimal(nil), do: "0"
  defp decimal(value), do: Decimal.to_string(value)
  defp parse_integer(nil), do: 0
  defp parse_integer(value), do: String.to_integer(to_string(value))
end
