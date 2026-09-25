defmodule AgentYard.Git.Provider do
  @moduledoc """
  Behaviour for forge integrations that manage repository changes.
  """

  @type config :: map()

  @callback clone(config(), String.t(), String.t(), String.t()) ::
              {:ok, String.t()} | {:error, term()}
  @callback create_branch(config(), String.t(), String.t()) ::
              {:ok, String.t()} | {:error, term()}
  @callback commit_and_push(config(), String.t(), String.t(), String.t()) ::
              :ok | {:error, term()}
  @callback open_change(config(), String.t(), String.t(), String.t()) ::
              {:ok, map()} | {:error, term()}
end
