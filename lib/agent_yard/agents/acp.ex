defmodule AgentYard.Agents.ACP do
  @moduledoc """
  Adapter boundary for Agent Client Protocol (ACP) runtimes.

  ACP implementations translate protocol messages into AgentYard's normalized
  events. Runtime transport and session negotiation are intentionally outside
  this MVP boundary.
  """

  alias AgentYard.Agents.Event

  @type callback :: (Event.t() -> any())
  @type state :: term()

  @callback prepare(map()) :: {:ok, map()} | {:error, term()}
  @callback start(map(), callback()) :: {:ok, state()} | {:error, term()}
  @callback follow_up(state(), String.t(), callback()) :: {:ok, state()} | {:error, term()}
  @callback cancel(state()) :: :ok
  @callback normalize(map()) :: {:ok, Event.t()} | :ignore | {:error, term()}
end
