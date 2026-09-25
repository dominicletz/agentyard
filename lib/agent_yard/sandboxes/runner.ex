defmodule AgentYard.Sandboxes.Runner do
  @moduledoc """
  Behaviour for preparing and executing a run workspace.
  """

  @callback prepare(map()) :: {:ok, map()} | {:error, term()}
  @callback cleanup(map()) :: :ok | {:error, term()}
  @callback command(map(), [String.t()]) :: {:ok, reference()} | {:error, term()}
end
