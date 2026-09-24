defmodule AgentYard.Git.Provider do
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
