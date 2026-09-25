defmodule AgentYard.Runs.Worker do
  @moduledoc """
  Oban entry point for starting queued runs.
  """

  use Oban.Worker, queue: :runs, max_attempts: 3

  alias AgentYard.Runs

  @impl true
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    case Runs.start_live_run(run_id) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
