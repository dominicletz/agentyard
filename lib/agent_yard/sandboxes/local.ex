defmodule AgentYard.Sandboxes.Local do
  @moduledoc """
  Development runner that executes commands on the local host.
  """

  @behaviour AgentYard.Sandboxes.Runner

  @impl true
  def prepare(config), do: {:ok, Map.put(config, :sandbox, :local)}

  @impl true
  def cleanup(_config), do: :ok

  @impl true
  def command(config, args) do
    task =
      Task.async(fn ->
        System.cmd(List.first(args), Enum.drop(args, 1), cd: config[:workspace])
      end)

    {:ok, task.ref}
  end
end
