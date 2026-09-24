defmodule AgentYard.Agents.Adapter do
  alias AgentYard.Agents.Event

  @type callback :: (Event.t() -> any())
  @type state :: term()

  @callback prepare(map()) :: {:ok, map()} | {:error, term()}
  @callback start(map(), callback()) :: {:ok, state()} | {:error, term()}
  @callback follow_up(state(), String.t(), callback()) :: {:ok, state()} | {:error, term()}
  @callback cancel(state()) :: :ok
  @callback normalize(map()) :: {:ok, Event.t()} | :ignore | {:error, term()}
end
