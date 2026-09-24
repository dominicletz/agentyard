defmodule AgentYardWeb.TeamLive.Settings do
  use AgentYardWeb, :live_view

  alias AgentYard.{Accounts, Secrets}

  @impl true
  def mount(_params, _session, socket) do
    team = socket.assigns.team

    {:ok,
     assign(socket,
       page_title: "Team settings",
       active_nav: :team,
       members: if(team, do: Accounts.list_members(team), else: []),
       secrets: if(team, do: Secrets.list_for_team(team.id), else: []),
       error: nil
     )}
  end

  @impl true
  def handle_event("add-secret", %{"name" => name, "value" => value}, socket) do
    case Secrets.put(socket.assigns.team.id, %{name: name, value: value, scope: "team"}) do
      {:ok, _secret} ->
        {:noreply,
         assign(socket, secrets: Secrets.list_for_team(socket.assigns.team.id), error: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, error: inspect(changeset.errors))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header"><div><p class="eyebrow">Governance</p><h1>Team settings</h1><p class="muted">Members, roles and write-only secrets for <%= @team && @team.name %>.</p></div></div>
    <div class="two-column">
      <section class="panel">
        <div class="panel-heading"><h2>Members</h2><span class="tag tag-muted"><%= length(@members) %> members</span></div>
        <div :for={member <- @members} class="list-row"><span class="avatar avatar-small"><%= initials(member.email) %></span><div><strong><%= member.name %></strong><small><%= member.email %></small></div><span class="role-pill"><%= member.role %></span></div>
        <div class="settings-note"><strong>Role policy</strong><p class="muted">Owners and admins can manage repositories, profiles and secrets. Members can start and follow runs in their team.</p></div>
      </section>
      <section class="panel">
        <div class="panel-heading"><h2>Secrets vault</h2><span class="ready-pill">● Encrypted</span></div>
        <p class="muted">Values are encrypted with the instance key, injected only into the selected runner, and never rendered again.</p>
        <div :for={secret <- @secrets} class="list-row"><span class="secret-icon">●</span><div><strong><%= secret.name %></strong><small><%= secret.scope %> scope · value hidden</small></div><span class="tag tag-muted">write-only</span></div>
        <%= if @error do %><p class="flash flash-error"><%= @error %></p><% end %>
        <form phx-submit="add-secret" class="stack-form secret-form"><label>Name<input name="name" placeholder="ANTHROPIC_API_KEY" required /></label><label>Value<input name="value" type="password" required /></label><button class="button button-secondary" type="submit">Store encrypted secret</button></form>
      </section>
    </div>
    """
  end

  defp initials(email) do
    email |> String.split("@") |> List.first() |> String.slice(0, 2) |> String.upcase()
  end
end
