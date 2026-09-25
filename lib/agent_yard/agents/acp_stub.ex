defmodule AgentYard.Agents.ACPStub do
  @moduledoc """
  Compilable ACP adapter boundary with an explicit runtime limitation.

  Selecting this provider never silently pretends to execute an ACP session:
  it emits a status and a normalized error so the run is visibly failed until
  a real ACP transport is installed.
  """

  @behaviour AgentYard.Agents.ACP

  alias AgentYard.Agents.Event

  @impl true
  def prepare(config), do: {:ok, config}

  @impl true
  def start(_config, callback) do
    callback.(Event.status("ACP adapter boundary selected"))
    callback.(Event.error("ACP runtime is not implemented"))
    {:ok, %{}}
  end

  @impl true
  def follow_up(_state, _prompt, _callback), do: {:error, :acp_not_implemented}

  @impl true
  def cancel(_state), do: :ok

  @impl true
  def normalize(_payload), do: :ignore
end
