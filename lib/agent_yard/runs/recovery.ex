defmodule AgentYard.Runs.Recovery do
  @moduledoc """
  Reconnects queued or interrupted runs when the control plane boots.

  A seed or deployment process may create a run before the long-lived web
  process starts. Recovery keeps the persisted state authoritative and makes
  the demo and single-node deployment resilient to restarts.
  """

  use GenServer
  require Logger

  alias AgentYard.Runs

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_args), do: {:ok, %{}, {:continue, :recover}}

  @impl true
  def handle_continue(:recover, state) do
    Enum.each(Runs.active_runs(), fn run ->
      case Runs.start_live_run(run.id) do
        {:ok, _pid} -> :ok
        {:error, reason} -> Logger.warning("Could not recover run #{run.id}: #{inspect(reason)}")
      end
    end)

    {:noreply, state}
  rescue
    error ->
      Logger.warning("Run recovery deferred: #{Exception.message(error)}")
      {:noreply, state}
  end
end
