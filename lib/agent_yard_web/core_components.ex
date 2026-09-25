defmodule AgentYardWeb.CoreComponents do
  @moduledoc """
  Shared UI components used by AgentYard LiveViews and layouts.
  """

  @cent Decimal.new("0.01")
  @zero Decimal.new("0")

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

  def money(nil), do: "0.00"

  def money(value) do
    amount = if is_struct(value, Decimal), do: value, else: Decimal.new(to_string(value))

    precision =
      if Decimal.compare(Decimal.abs(amount), @cent) == :lt and
           Decimal.compare(amount, @zero) != :eq do
        4
      else
        2
      end

    Decimal.to_string(Decimal.round(amount, precision))
  end

  def format_payload(value) when is_binary(value), do: value
  def format_payload(value), do: inspect(value, pretty: true, width: 100)
end
