defmodule AgentYardWeb.RunsLive.New do
  use AgentYardWeb, :live_view

  alias AgentYard.{AgentProfiles, Repositories, Runs}

  @impl true
  def mount(_params, _session, socket) do
    team = socket.assigns.team

    {:ok,
     socket
     |> assign(:page_title, "New run")
     |> assign(:active_nav, :new_run)
     |> assign(:repositories, if(team, do: Repositories.list_for_team(team.id), else: []))
     |> assign(:profiles, if(team, do: AgentProfiles.list_for_team(team.id), else: []))
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("start", params, socket) do
    with %{} = user <- socket.assigns.current_user,
         %{} = team <- socket.assigns.team,
         {:ok, run} <- Runs.create_run(user, team, params),
         {:ok, _pid} <- Runs.start_run(run) do
      {:noreply, push_navigate(socket, to: ~p"/runs/#{run.id}")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, :error, "Could not start run: #{inspect(reason)}")}

      _ ->
        {:noreply, assign(socket, :error, "A demo team is required before starting a run.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div><p class="eyebrow">Runs</p><h1>New run</h1><p class="muted">Start an async coding agent against a connected repository.</p></div>
      <.link navigate={~p"/runs"} class="button button-secondary">Cancel</.link>
    </div>

    <div class="composer-layout">
      <section class="panel composer-panel">
        <form phx-submit="start">
          <%= if @error do %><p class="flash flash-error"><%= @error %></p><% end %>
          <div class="form-grid two">
            <label>Repository
              <select name="repository_id" required>
                <option value="">Choose a repository</option>
                <option :for={repo <- @repositories} value={repo.id}><%= repo.name %> (<%= repo.forge %>)</option>
              </select>
            </label>
            <label>Base branch
              <input name="base_branch" value="main" required />
            </label>
          </div>
          <label>Agent profile
            <select name="agent_profile_id" required>
              <option value="">Choose an agent profile</option>
              <option :for={profile <- @profiles} value={profile.id}><%= profile.name %> · <%= profile.provider %></option>
            </select>
          </label>
          <label>Prompt
            <textarea name="prompt" rows="8" required placeholder="Describe the change you want the agent to make…"></textarea>
          </label>
          <div class="form-grid two">
            <label>Issue or PR link <span class="muted">(optional)</span><input name="issue_url" placeholder="https://github.com/…" /></label>
            <label>Environment
              <select name="environment">
                <option value="local">Local development</option>
                <option value="docker">Docker sandbox</option>
              </select>
            </label>
          </div>
          <div class="form-grid two">
            <label>Timeout (seconds)<input name="timeout_seconds" type="number" min="1" value="3600" /></label>
            <label>Maximum tool turns <span class="muted">(optional)</span><input name="max_turns" type="number" min="1" /></label>
          </div>
          <div class="check-row">
            <label class="checkbox"><input type="checkbox" name="auto_pr" value="true" checked /> Auto-open PR / MR</label>
            <label class="checkbox"><input type="checkbox" name="run_tests" value="true" checked /> Run tests</label>
          </div>
          <button class="button button-primary" type="submit">Start run</button>
        </form>
      </section>

      <aside class="stack">
        <section class="panel side-card">
          <div class="panel-heading"><h2>Sandbox preview</h2><span class="ready-pill">● Image ready</span></div>
          <dl class="detail-list"><div><dt>Image</dt><dd>local/fake-runner:demo</dd></div><div><dt>CPU / RAM</dt><dd>2 vCPU · 2 GB</dd></div><div><dt>Egress</dt><dd>Allowlist · disabled in demo</dd></div><div><dt>Secrets</dt><dd>Scoped team secrets</dd></div></dl>
        </section>
        <section class="panel side-card"><h2>What happens next</h2><ol class="steps"><li>Workspace is cloned at the selected ref.</li><li>The adapter emits a normalized live timeline.</li><li>Changes are committed to an agent branch.</li><li>A PR/MR can be opened for review.</li></ol></section>
      </aside>
    </div>
    """
  end
end
