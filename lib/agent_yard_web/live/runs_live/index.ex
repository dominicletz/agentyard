defmodule AgentYardWeb.RunsLive.Index do
  use AgentYardWeb, :live_view

  alias AgentYard.Runs

  @impl true
  def mount(_params, _session, socket) do
    team = socket.assigns.team
    if connected?(socket) and team, do: Runs.subscribe_team(team)

    {:ok,
     socket
     |> assign(:page_title, "Overview")
     |> assign(:active_nav, :runs)
     |> assign(:filter_status, "all")
     |> assign(:filter_query, "")
     |> assign_runs()}
  end

  @impl true
  def handle_event("filter", %{"status" => status, "query" => query}, socket) do
    {:noreply,
     assign_runs(socket, %{status: status, query: query})
     |> assign(:filter_status, status)
     |> assign(:filter_query, query)}
  end

  @impl true
  def handle_info({:run_updated, _run}, socket), do: {:noreply, assign_runs(socket)}
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <p class="eyebrow">Workspace pulse</p>
        <h1>Runs</h1>
        <p class="muted">All agent sessions across your team repositories.</p>
      </div>
      <.link navigate={~p"/runs/new"} class="button button-primary">＋ New run</.link>
    </div>

    <div class="metric-grid">
      <div class="metric-card"><span>Running</span><strong class="metric-blue"><%= count(@runs, "running") %></strong></div>
      <div class="metric-card"><span>Queued</span><strong><%= count(@runs, "queued") %></strong></div>
      <div class="metric-card"><span>Succeeded (24h)</span><strong class="metric-green"><%= count(@runs, "succeeded") %></strong></div>
      <div class="metric-card"><span>Spend (visible)</span><strong>$<%= money(total_cost(@runs)) %></strong></div>
    </div>

    <section class="panel runs-panel">
      <div class="panel-heading">
        <h2>Recent runs</h2>
        <form phx-change="filter" class="filter-bar">
          <input type="search" name="query" value={@filter_query} placeholder="Search prompt or branch" />
          <select name="status">
            <option value="all" selected={@filter_status == "all"}>All statuses</option>
            <option value="running" selected={@filter_status == "running"}>Running</option>
            <option value="queued" selected={@filter_status == "queued"}>Queued</option>
            <option value="succeeded" selected={@filter_status == "succeeded"}>Succeeded</option>
            <option value="failed" selected={@filter_status == "failed"}>Failed</option>
          </select>
        </form>
      </div>
      <div class="table-wrap">
        <table class="runs-table">
          <thead><tr><th>Status</th><th>Run</th><th>Repository</th><th>Agent</th><th>Trigger</th><th>Cost</th><th>Started</th></tr></thead>
          <tbody>
            <tr :for={run <- @runs} id={"run-#{run.id}"}>
              <td><.status_badge status={run.status} /></td>
              <td>
                <.link navigate={~p"/runs/#{run.id}"} class="run-title"><%= run.session.title %></.link>
                <small><%= String.slice(run.branch_name || "", 0, 38) %></small>
              </td>
              <td><span class="tag"><%= run.session.repository.name %></span></td>
              <td><%= run.session.agent_profile.name %></td>
              <td><span class="tag tag-muted"><%= run.trigger %></span></td>
              <td>$<%= money(run.cost_usd) %></td>
              <td class="muted"><%= relative_time(run.inserted_at) %></td>
            </tr>
            <tr :if={@runs == []}><td colspan="7" class="empty-state">No runs match these filters.</td></tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp assign_runs(socket, filters \\ nil) do
    team = socket.assigns.team

    filters =
      filters || %{status: socket.assigns[:filter_status], query: socket.assigns[:filter_query]}

    runs = if team, do: Runs.list_runs(team, filters), else: []
    assign(socket, :runs, runs)
  end

  defp count(runs, status), do: Enum.count(runs, &(&1.status == status))

  defp total_cost(runs),
    do: Enum.reduce(runs, Decimal.new("0"), &Decimal.add(&1.cost_usd || 0, &2))

  defp relative_time(nil), do: "—"
  defp relative_time(datetime), do: Calendar.strftime(datetime, "%d %b %H:%M")
end
