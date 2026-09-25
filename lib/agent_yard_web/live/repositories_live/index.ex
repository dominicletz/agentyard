defmodule AgentYardWeb.RepositoriesLive.Index do
  use AgentYardWeb, :live_view

  alias AgentYard.{Accounts, Repositories}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Repository",
       active_nav: :repositories,
       repositories: repositories(socket),
       error: nil
     )}
  end

  @impl true
  def handle_event("connect", params, socket) do
    case Accounts.authorize(socket.assigns.current_user, socket.assigns.team, ~w(owner admin)) do
      :ok ->
        case Repositories.create(socket.assigns.team.id, params) do
          {:ok, _repository} -> {:noreply, assign(socket, repositories: repositories(socket))}
          {:error, changeset} -> {:noreply, assign(socket, error: inspect(changeset.errors))}
        end

      {:error, :forbidden} ->
        {:noreply, assign(socket, error: "Only owners and admins can connect repositories.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header"><div><p class="eyebrow">Workspace</p><h1>Repositories</h1><p class="muted">Connect the GitHub and GitLab projects your agents can work on.</p></div></div>
    <div class="two-column">
      <section class="panel">
        <div class="panel-heading"><h2>Connected repositories</h2><span class="tag tag-muted"><%= length(@repositories) %> connected</span></div>
        <div :if={@repositories == []} class="empty-state">No repositories connected yet.</div>
        <div :for={repo <- @repositories} class="list-row">
          <span class="repo-icon"><%= String.first(repo.forge) |> String.upcase() %></span>
          <div><strong><%= repo.name %></strong><small><%= repo.remote_url %></small></div>
          <span class="tag tag-muted"><%= repo.default_branch %></span>
        </div>
      </section>
      <section class="panel">
        <div class="panel-heading"><h2>Connect a repository</h2></div>
        <%= if @error do %><p class="flash flash-error"><%= @error %></p><% end %>
        <form phx-submit="connect" class="stack-form">
          <label>Name<input name="name" placeholder="acme/payments-api" required /></label>
          <label>Forge<select name="forge"><option value="github">GitHub</option><option value="gitlab">GitLab</option></select></label>
          <label>Clone URL<input name="remote_url" placeholder="https://github.com/acme/project.git" required /></label>
          <label>Default branch<input name="default_branch" value="main" required /></label>
          <button class="button button-primary" type="submit">Connect repository</button>
        </form>
      </section>
    </div>
    """
  end

  defp repositories(%{assigns: %{team: %{id: id}}}), do: Repositories.list_for_team(id)
  defp repositories(_), do: []
end
