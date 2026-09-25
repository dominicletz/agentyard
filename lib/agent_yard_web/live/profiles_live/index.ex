defmodule AgentYardWeb.ProfilesLive.Index do
  use AgentYardWeb, :live_view

  alias AgentYard.AgentProfiles

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Agent profiles",
       active_nav: :profiles,
       profiles: profiles(socket),
       error: nil
     )}
  end

  @impl true
  def handle_event("create", params, socket) do
    case AgentProfiles.create(socket.assigns.team.id, params) do
      {:ok, _profile} -> {:noreply, assign(socket, profiles: profiles(socket), error: nil)}
      {:error, changeset} -> {:noreply, assign(socket, error: inspect(changeset.errors))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header"><div><p class="eyebrow">Workspace</p><h1>Agent profiles</h1><p class="muted">Choose the adapter, model and guardrails that runs use.</p></div></div>
    <div class="two-column">
      <section class="panel">
        <div class="panel-heading"><h2>Profiles</h2><span class="tag tag-muted"><%= length(@profiles) %> profiles</span></div>
        <div :for={profile <- @profiles} class="profile-card">
          <div class="profile-card-top"><span class={"provider-icon provider-#{profile.provider}"}><%= provider_mark(profile.provider) %></span><div><strong><%= profile.name %></strong><small><%= profile.provider %> · <%= profile.model || "default model" %></small></div><span class="ready-pill">● Ready</span></div>
          <p class="muted"><%= profile.instructions || "No additional instructions configured." %></p>
          <div class="profile-meta"><span>Permission: <%= profile.permission_mode %></span><span>Budget: $<%= money(profile.budget_usd || Decimal.new("5.00")) %></span></div>
        </div>
        <div :if={@profiles == []} class="empty-state">No profiles configured.</div>
      </section>
      <section class="panel">
        <div class="panel-heading"><h2>New profile</h2></div>
        <%= if @error do %><p class="flash flash-error"><%= @error %></p><% end %>
        <form phx-submit="create" class="stack-form">
          <label>Name<input name="name" value="Fake demo agent" required /></label>
          <label>Provider<select name="provider"><option value="fake">Fake / scripted</option><option value="claude_code">Claude Code</option><option value="cursor_cli">Cursor CLI</option><option value="openrouter">OpenRouter</option></select></label>
          <label>Model<input name="model" placeholder="claude-sonnet-4-5" /></label>
          <label>OpenAI-compatible base URL <span class="muted">(optional)</span><input name="base_url" placeholder="https://openrouter.ai/api/v1" /></label>
          <label>Permission mode<select name="permission_mode"><option value="accept_edits">Accept edits</option><option value="ask">Ask</option><option value="plan">Plan</option><option value="bypass">Bypass</option></select></label>
          <label>Instructions<textarea name="instructions" rows="4" placeholder="Repository-specific guidance…"></textarea></label>
          <label>Budget (USD)<input name="budget_usd" value="5.00" type="number" step="0.01" min="0.01" /></label>
          <button class="button button-primary" type="submit">Create profile</button>
        </form>
      </section>
    </div>
    """
  end

  defp profiles(%{assigns: %{team: %{id: id}}}), do: AgentProfiles.list_for_team(id)
  defp profiles(_), do: []
  defp provider_mark("claude_code"), do: "C"
  defp provider_mark("cursor_cli"), do: "↗"
  defp provider_mark("openrouter"), do: "O"
  defp provider_mark(_), do: "F"
end
