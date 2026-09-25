defmodule AgentYard.Runs do
  @moduledoc """
  Durable sessions, runs and replayable event logs.
  """

  import Ecto.Query, warn: false
  alias AgentYard.Accounts.{Team, User}
  alias AgentYard.AgentProfiles.Profile
  alias AgentYard.Agents.Event
  alias AgentYard.Audit
  alias AgentYard.Repo
  alias AgentYard.Repositories.Repository
  alias AgentYard.Runs.{Run, RunEvent, RunProcess, Session, Worker}

  @topic_prefix "run:"
  @team_topic_prefix "team:"
  @mutation_roles ~w(owner admin member)

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
    with :ok <- AgentYard.Accounts.authorize(user, %Team{id: team_id}, @mutation_roles) do
      create_run_for_authorized(user, team_id, attrs)
    end
  end

  defp create_run_for_authorized(%User{} = user, team_id, attrs) do
    repository = Repo.get_by!(Repository, id: attr(attrs, :repository_id), team_id: team_id)
    profile = Repo.get_by!(Profile, id: attr(attrs, :agent_profile_id), team_id: team_id)
    branch = attr(attrs, :branch_name) || generated_branch()
    prompt = attr(attrs, :prompt)
    environment = execution_environment(attr(attrs, :environment), profile.provider)

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
        auto_pr: boolean_attr(attrs, :auto_pr, true),
        environment: environment,
        issue_url: attr(attrs, :issue_url),
        timeout_seconds: integer_attr(attrs, :timeout_seconds, 3600),
        max_turns: integer_attr(attrs, :max_turns, nil),
        status: "queued"
      })
      |> Repo.insert()
    end)
    |> unwrap_transaction()
    |> audit_created(user)
  end

  defp audit_created(%Run{} = run, user) do
    _ = Audit.log(run.team_id, user.id, "run.created", "run", run.id)
    run
  end

  defp audit_created(result, _user), do: result

  def follow_up(%Run{} = run, %User{} = user, prompt) when is_binary(prompt) do
    with :ok <- authorize_run(run, user) do
      session = Repo.get!(Session, run.session_id)

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
        auto_pr: run.auto_pr,
        environment: run.environment,
        issue_url: run.issue_url,
        timeout_seconds: run.timeout_seconds,
        max_turns: run.max_turns,
        status: "queued"
      })
      |> Repo.insert()
    end
  end

  def enqueue_run(%Run{id: run_id, team_id: team_id, session_id: session_id}) do
    %{"run_id" => run_id, "team_id" => team_id, "session_id" => session_id}
    |> Worker.new()
    |> Oban.insert()
  end

  @doc """
  Queue a run for asynchronous execution.

  The old direct-start entry point is intentionally retained as the public API,
  but it now inserts an Oban job so LiveViews and REST callers never block on
  clone, sandbox or provider startup.
  """
  def start_run(%Run{} = run), do: enqueue_run(run)

  def start_live_run(run_id) do
    case get_run(run_id) do
      %Run{status: "queued"} = run ->
        start_queued_run(run)

      %Run{status: "running"} = run ->
        recover_running_run(run)

      %Run{status: status} when status in ["succeeded", "failed", "cancelled"] ->
        {:error, {:invalid_run_status, status}}

      nil ->
        {:error, :run_not_found}
    end
  end

  defp start_queued_run(run) do
    if concurrency_available?(run),
      do: start_run_process(run.id),
      else: {:error, :concurrency_limit}
  end

  defp recover_running_run(run) do
    case Registry.lookup(AgentYard.Runs.Registry, run.id) do
      [{pid, _}] -> {:ok, pid}
      [] -> start_run_process(run.id)
    end
  end

  defp start_run_process(run_id) do
    child = {RunProcess, run_id}

    case DynamicSupervisor.start_child(AgentYard.Runs.Supervisor, child) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      result -> result
    end
  end

  def team_concurrency_limit,
    do: Application.get_env(:agentyard, :run_concurrency_limit, 2)

  def concurrency_available?(%Run{team_id: team_id, session_id: session_id}) do
    running_count =
      from(r in Run, where: r.team_id == ^team_id and r.status == "running", select: count(r.id))
      |> Repo.one()

    session_running? =
      from(r in Run,
        where: r.session_id == ^session_id and r.status == "running",
        select: count(r.id)
      )
      |> Repo.one()

    running_count < team_concurrency_limit() and session_running? == 0
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

      payload = Event.to_payload(event)

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
    attrs = %{
      input_tokens: usage_value(usage, "input_tokens", :input_tokens, run.input_tokens),
      output_tokens: usage_value(usage, "output_tokens", :output_tokens, run.output_tokens),
      cache_tokens: usage_value(usage, "cache_tokens", :cache_tokens, run.cache_tokens)
    }

    case usage_cost(usage) do
      nil -> update_run(run, attrs)
      cost -> update_run(run, Map.put(attrs, :cost_usd, cost))
    end
  end

  def update_status(%Run{} = run, status, attrs \\ %{}) do
    case update_run(run, Map.merge(attrs, %{status: status})) do
      {:ok, updated} = result ->
        _ =
          Audit.log(
            updated.team_id,
            updated.user_id,
            "run.status_changed",
            "run",
            updated.id,
            %{status: status}
          )

        result

      error ->
        error
    end
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
    AgentYard.Accounts.authorize(user, %Team{id: team_id}, @mutation_roles)
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

  defp boolean_attr(attrs, key, default) do
    case Map.fetch(attrs, key) do
      {:ok, value} ->
        parse_boolean(value)

      :error ->
        case Map.fetch(attrs, to_string(key)) do
          {:ok, value} -> parse_boolean(value)
          :error -> default
        end
    end
  end

  defp parse_boolean(value) when value in [true, "true", "1", 1], do: true
  defp parse_boolean(_value), do: false

  defp integer_attr(attrs, key, default) do
    case attr(attrs, key) do
      nil ->
        default

      value when is_integer(value) ->
        value

      value ->
        case Integer.parse(to_string(value)) do
          {integer, _} -> integer
          :error -> default
        end
    end
  end

  defp execution_environment(value, _provider) when value in ["docker", :docker],
    do: "docker"

  defp execution_environment(value, _provider) when value in ["local", :local],
    do: "local"

  defp execution_environment(value, _provider)
       when value in ["Repository default", "repository_default", nil, ""],
       do: "local"

  defp execution_environment(_value, _provider), do: "local"

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

  defp usage_value(usage, string_key, atom_key, current),
    do: Map.get(usage, string_key) || Map.get(usage, atom_key) || current || 0

  defp usage_cost(usage) do
    Map.get(usage, "cost_usd") ||
      Map.get(usage, :cost_usd) ||
      Map.get(usage, "total_cost_usd") ||
      Map.get(usage, :total_cost_usd) ||
      Map.get(usage, "cost") ||
      Map.get(usage, :cost)
  end

  defp unwrap_transaction({:ok, value}), do: value
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
