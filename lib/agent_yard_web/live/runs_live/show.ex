defmodule AgentYardWeb.RunsLive.Show do
  use AgentYardWeb, :live_view

  alias AgentYard.Runs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    team = socket.assigns.team
    run = Runs.get_run!(id, team)
    if connected?(socket), do: Runs.subscribe(run)

    {:ok,
     socket
     |> assign(:page_title, run.session.title)
     |> assign(:active_nav, :runs)
     |> assign(:run, run)
     |> assign(:events, Runs.list_events(run))
     |> assign(:follow_up_error, nil)}
  end

  @impl true
  def handle_event("stop", _params, socket) do
    case Runs.cancel(socket.assigns.run, socket.assigns.current_user) do
      {:ok, run} ->
        {:noreply, assign(socket, :run, Runs.get_run!(run.id, socket.assigns.team))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not stop run: #{inspect(reason)}")}
    end
  end

  def handle_event("follow-up", %{"prompt" => prompt}, socket) do
    prompt = String.trim(prompt)

    if prompt == "" do
      {:noreply, assign(socket, :follow_up_error, "Write a follow-up before sending it.")}
    else
      case Runs.follow_up(socket.assigns.run, socket.assigns.current_user, prompt) do
        {:ok, run} ->
          {:ok, _pid} = Runs.start_run(run)
          {:noreply, push_navigate(socket, to: ~p"/runs/#{run.id}")}

        {:error, reason} ->
          {:noreply, assign(socket, :follow_up_error, inspect(reason))}
      end
    end
  end

  @impl true
  def handle_info({:run_event, _run_id, event}, socket) do
    {:noreply, update(socket, :events, &append_event(&1, event))}
  end

  def handle_info({:run_updated, run}, socket) do
    run = Runs.get_run!(run.id, socket.assigns.team)
    {:noreply, assign(socket, run: run, page_title: run.session.title)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="detail-header">
      <div>
        <div class="breadcrumbs-inline"><.link navigate={~p"/runs"}>Runs</.link><span>›</span><span>Run detail</span></div>
        <h1><%= @run.session.title %></h1>
        <div class="run-meta"><span class="tag"><%= @run.session.repository.name %></span><span>branch <code><%= @run.branch_name %></code></span><span>· <%= @run.session.agent_profile.name %></span><span>· <%= @run.trigger %></span></div>
      </div>
      <div class="detail-actions">
        <.status_badge status={@run.status} />
        <button :if={@run.status in ["queued", "running"]} class="button button-danger" phx-click="stop" data-confirm="Stop this run?">■ Stop</button>
        <a :if={@run.pr_url || @run.merge_request_url} class="button button-secondary" href={@run.pr_url || @run.merge_request_url} target="_blank">Open PR / MR ↗</a>
        <button class="button button-secondary" phx-click={JS.dispatch("agentyard:copy", to: "#branch-name")}><span id="branch-name"><%= @run.branch_name %></span></button>
      </div>
    </div>

    <div class="metric-grid detail-metrics">
      <div class="metric-card"><span>Elapsed</span><strong><%= elapsed(@run) %></strong></div>
      <div class="metric-card"><span>Tokens</span><strong><%= (@run.input_tokens || 0) + (@run.output_tokens || 0) %></strong><small><%= @run.input_tokens || 0 %> in · <%= @run.output_tokens || 0 %> out</small></div>
      <div class="metric-card"><span>Cost</span><strong>$<%= money(@run.cost_usd) %></strong></div>
      <div class="metric-card"><span>Files touched</span><strong>—</strong><small>available after provider diff</small></div>
    </div>

    <div class="detail-layout">
      <section class="panel timeline-panel">
        <div class="panel-tabs"><span class="active">Timeline</span><span>Terminal</span><span>Diff</span><span>Artifacts</span></div>
        <div class="timeline">
          <div :for={event <- @events} class={"timeline-event event-#{event.kind}"}>
            <div class="event-rail"><span class="event-dot"></span></div>
            <div class="event-body">
              <div class="event-heading"><span class="event-kind"><%= event_label(event.kind) %></span><time><%= event_time(event.inserted_at) %></time></div>
              <p :if={event_text(event)} class="event-text"><%= event_text(event) %></p>
              <pre :if={payload = event_payload(event)}><%= format_payload(payload) %></pre>
              <div :if={event.kind == "usage"} class="usage-line">input <%= event.payload["usage"]["input_tokens"] %> · output <%= event.payload["usage"]["output_tokens"] %></div>
            </div>
          </div>
          <div :if={@events == []} class="empty-state">Waiting for the first event…</div>
        </div>
        <form :if={@run.status in ["queued", "running", "succeeded"]} phx-submit="follow-up" class="follow-up">
          <%= if @follow_up_error do %><p class="flash flash-error"><%= @follow_up_error %></p><% end %>
          <textarea name="prompt" rows="3" placeholder="Send a follow-up to the running agent…"></textarea>
          <div class="follow-up-footer"><span class="muted">Enter to send · Shift+Enter newline</span><button class="button button-primary" type="submit">Send follow-up</button></div>
        </form>
      </section>

      <aside class="stack">
        <section class="panel result-card"><div class="panel-heading"><h2>Result</h2><.status_badge status={@run.status} /></div><dl class="detail-list"><div><dt>Branch</dt><dd><code><%= @run.branch_name %></code></dd></div><div><dt>Session</dt><dd><%= @run.session.id |> String.slice(0, 8) %>…</dd></div><div><dt>Base ref</dt><dd><%= @run.base_branch %></dd></div><div :if={@run.error}><dt>Error</dt><dd class="error-text"><%= @run.error %></dd></div></dl></section>
        <section class="panel usage-card"><div class="panel-heading"><h2>Usage</h2><span class="muted">this run</span></div><dl class="detail-list"><div><dt>Input</dt><dd><%= @run.input_tokens || 0 %> tok</dd></div><div><dt>Output</dt><dd><%= @run.output_tokens || 0 %> tok</dd></div><div><dt>Budget</dt><dd>$<%= money(@run.session.agent_profile.budget_usd || Decimal.new("5.00")) %></dd></div></dl><div class="progress"><span style="width: 38%"></span></div></section>
        <section class="panel side-card"><h2>Workspace</h2><p class="muted">The local demo runner uses an ephemeral workspace. Docker and forge adapters can be selected per repository.</p></section>
      </aside>
    </div>
    """
  end

  defp append_event(events, event),
    do: if(Enum.any?(events, &(&1.id == event.id)), do: events, else: events ++ [event])

  defp event_label("assistant_delta"), do: "Assistant"
  defp event_label("tool_call"), do: "Tool call"
  defp event_label("tool_result"), do: "Tool result"
  defp event_label("status"), do: "Setup"
  defp event_label("usage"), do: "Usage"
  defp event_label("result"), do: "Result"
  defp event_label("done"), do: "Finished"
  defp event_label("error"), do: "Error"
  defp event_label(kind), do: kind

  defp event_text(%{kind: "assistant_delta", payload: %{"text" => text}}), do: text
  defp event_text(%{kind: "status", payload: %{"message" => message}}), do: message
  defp event_text(%{kind: "result", payload: %{"message" => message}}), do: message
  defp event_text(%{kind: "error", payload: %{"message" => message}}), do: message
  defp event_text(%{kind: "tool_call", payload: %{"tool" => tool}}), do: tool
  defp event_text(_), do: nil

  defp event_payload(%{payload: payload}) do
    payload["input"] || payload["output"] || payload["text"]
  end

  defp event_time(nil), do: ""
  defp event_time(time), do: Calendar.strftime(time, "%H:%M:%S")

  defp elapsed(%{started_at: nil}), do: "—"

  defp elapsed(%{started_at: started_at, finished_at: nil}),
    do: duration(started_at, DateTime.utc_now())

  defp elapsed(%{started_at: started_at, finished_at: finished_at}),
    do: duration(started_at, finished_at)

  defp duration(started_at, ended_at) do
    seconds = max(DateTime.diff(ended_at, started_at), 0)
    "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
  end
end
