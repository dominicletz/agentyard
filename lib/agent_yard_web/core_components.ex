defmodule AgentYardWeb.CoreComponents do
  use Phoenix.Component

  attr(:flash, :map, required: true)

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" aria-live="polite">
      <p :if={message = Phoenix.Flash.get(@flash, :info)} class="flash flash-info">{message}</p>
      <p :if={message = Phoenix.Flash.get(@flash, :error)} class="flash flash-error">{message}</p>
    </div>
    """
  end

  attr(:status, :string, required: true)

  def status_badge(assigns) do
    ~H"""
    <span class={"status-badge status-#{@status}"}><%= human_status(@status) %></span>
    """
  end

  def human_status(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
