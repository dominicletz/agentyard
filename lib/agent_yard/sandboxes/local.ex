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

  @impl true
  def port(config, [executable | args]) do
    if File.dir?(config[:workspace]) do
      {:ok,
       Port.open({:spawn_executable, to_charlist(executable)}, [
         :binary,
         :exit_status,
         {:line, 1_048_576},
         {:args, Enum.map(args, &to_charlist/1)},
         {:cd, to_charlist(config[:workspace])},
         {:env, environment(config[:env] || %{})}
       ])}
    else
      {:error, {:workspace_not_found, config[:workspace]}}
    end
  end

  defp environment(env),
    do: Enum.map(env, fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
end
