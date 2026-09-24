defmodule AgentYard.Runs do
  @moduledoc """
  Durable sessions, runs and replayable event logs.
  """

  import Ecto.Query, warn: false
  alias AgentYard.Accounts.{Team, User}
  alias AgentYard.AgentProfiles.Profile
  alias AgentYard.Repositories.Repository
  alias AgentYard.Repo
  alias AgentYard.Runs.{Run, RunEvent, Session}

  @topic_prefix "run:"
  @team_topic_prefix "team:"

  def list_runs(%Team{id: team_id}, filters \\ %{}) do
    Run
    |> where([r], r.team_id == ^team_id)
    |> maybe_filter_status(filters)
    |> maybe_filter_query(filters)
    |> order_by([r], desc: r.inserted_at)
    |> limit(100)
    |> preload([:user, session: [:repository, :agent_profile]])
    |> Repo.all()
  end

  def get_run!(id, %Team{id: team_id}) do
    Run
    |> where([r], r.id == ^id and r.team_id == ^team_id)
    |> preload([:user, session: [:repository, :agent_profile]])
    |> Repo.one!()
  end

  def get_run(id) do
    Run
    |> preload([:user, session: [:repository, :agent_profile]])
    |> Repo.get(id)
  end

  def active_runs do
    from(r in Run,
      where: r.status in ["queued", "running"],
      select: r
    )
    |> Repo.all()
  end

  def create_run(%User{} = user, %Team{id: team_id}, attrs) do
    repository = Repo.get_by!(Repository, id: attr(attrs, :repository_id), team_id: team_id)
    profile = Repo.get_by!(Profile, id: attr(attrs, :agent_profile_id), team_id: team_id)
    branch = attr(attrs, :branch_name) || generated_branch()
    prompt = attr(attrs, :prompt)

    Repo.transaction(fn ->
      {:ok, session} =
        %Session{}
        |> Session.changeset(%{
          team_id: team_id,
          repository_id: repository.id,
          agent_profile_id: profile.id,
          title: title_from_prompt(prompt),
          branch_name: branch
        })
        |> Repo.insert()

      %Run{}
      |> Run.changeset(%{
        team_id: team_id,
        user_id: user.id,
        session_id: session.id,
        prompt: prompt,
        trigger: attr(attrs, :trigger) || "ui",
        base_branch: attr(attrs, :base_branch) || repository.default_branch,
        branch_name: branch,
        adapter: profile.provider,
        status: "queued"
      })
      |> Repo.insert()
    end)
    |> unwrap_transaction()
  end

  def follow_up(%Run{} = run, %User{} = user, prompt) when is_binary(prompt) do
    with :ok <- authorize_run(run, user),
         session <- Repo.get!(Session, run.session_id),
         {:ok, new_run} <-
           %Run{}
           |> Run.changeset(%{
             team_id: run.team_id,
             user_id: user.id,
             session_id: session.id,
             prompt: prompt,
             trigger: "follow_up",
             base_branch: run.base_branch,
             branch_name: run.branch_name,
             adapter: run.adapter,
             status: "queued"
           })
           |> Repo.insert() do
      {:ok, new_run}
    end
  end

  def enqueue_run(%Run{id: run_id}) do
    run_id
    |> AgentYard.Runs.Worker.new()
    |> Oban.insert()
  end

  def start_run(%Run{id: run_id}), do: start_live_run(run_id)

  def start_live_run(run_id) do
    child = {AgentYard.Runs.RunProcess, run_id}

    case DynamicSupervisor.start_child(AgentYard.Runs.Supervisor, child) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      result -> result
    end
  end

  def cancel(%Run{} = run, %User{} = user) do
    with :ok <- authorize_run(run, user) do
      result =
        case Registry.lookup(AgentYard.Runs.Registry, run.id) do
          [{pid, _}] -> GenServer.call(pid, :cancel)
          [] -> :ok
        end

      if result == :ok do
        run
        |> Run.changeset(%{status: "cancelled", finished_at: DateTime.utc_now()})
        |> Repo.update()
      else
        result
      end
    end
  end

  def record_event(%Run{id: run_id}, event) do
    Repo.transaction(fn ->
      sequence =
        from(e in RunEvent, where: e.run_id == ^run_id, select: max(e.sequence))
        |> Repo.one()
        |> Kernel.||(0)
        |> Kernel.+(1)

      payload = AgentYard.Agents.Event.to_payload(event)

      {:ok, record} =
        %RunEvent{}
        |> RunEvent.changeset(%{
          run_id: run_id,
          sequence: sequence,
          kind: event.type,
          payload: payload
        })
        |> Repo.insert()

      record
    end)
  end

  def apply_event(%Run{} = run, %AgentYard.Agents.Event{type: "usage", usage: usage}) do
    update_usage(run, usage)
  end

  def apply_event(%Run{} = run, %AgentYard.Agents.Event{type: "result"} = event) do
    attrs = %{cost_usd: event.cost_usd || run.cost_usd || Decimal.new("0")}
    update_run(run, attrs)
  end

  def apply_event(%Run{} = run, _event), do: {:ok, run}

  def update_usage(%Run{} = run, usage) do
    update_run(run, %{
      input_tokens: usage["input_tokens"] || usage[:input_tokens] || run.input_tokens || 0,
      output_tokens: usage["output_tokens"] || usage[:output_tokens] || run.output_tokens || 0,
      cache_tokens: usage["cache_tokens"] || usage[:cache_tokens] || run.cache_tokens || 0
    })
  end

  def update_status(%Run{} = run, status, attrs \\ %{}) do
    update_run(run, Map.merge(attrs, %{status: status}))
  end

  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  def list_events(%Run{id: run_id}, after_sequence \\ 0) do
    from(e in RunEvent,
      where: e.run_id == ^run_id and e.sequence > ^after_sequence,
      order_by: [asc: e.sequence]
    )
    |> Repo.all()
  end

  def subscribe(%Run{id: run_id}), do: Phoenix.PubSub.subscribe(AgentYard.PubSub, topic(run_id))

  def broadcast(%Run{id: run_id, team_id: team_id}, message) do
    Phoenix.PubSub.broadcast(AgentYard.PubSub, topic(run_id), message)
    Phoenix.PubSub.broadcast(AgentYard.PubSub, team_topic(team_id), message)
  end

  def topic(run_id), do: @topic_prefix <> to_string(run_id)
  def team_topic(team_id), do: @team_topic_prefix <> to_string(team_id)

  def subscribe_team(%Team{id: team_id}),
    do: Phoenix.PubSub.subscribe(AgentYard.PubSub, team_topic(team_id))

  def authorize_run(%Run{team_id: team_id}, %User{} = user) do
    case AgentYard.Accounts.team_for_user(user) do
      %Team{id: ^team_id} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp maybe_filter_status(query, %{status: status}) when status not in [nil, "", "all"],
    do: where(query, [r], r.status == ^status)

  defp maybe_filter_status(query, %{"status" => status}),
    do: maybe_filter_status(query, %{status: status})

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_query(query, %{query: value}) when is_binary(value) and value != "",
    do: where(query, [r], ilike(r.prompt, ^"%#{value}%"))

  defp maybe_filter_query(query, %{"query" => value}),
    do: maybe_filter_query(query, %{query: value})

  defp maybe_filter_query(query, _), do: query

  defp attr(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, to_string(key))

  defp generated_branch do
    "agent/#{Date.utc_today()}/" <> (Ecto.UUID.generate() |> String.slice(0, 8))
  end

  defp title_from_prompt(prompt) do
    prompt
    |> to_string()
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 100)
  end

  defp unwrap_transaction({:ok, value}), do: value
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
