defmodule AgentYard.Sandboxes.Docker do
  @moduledoc """
  Local Docker runner with per-run workspace and resource limits.
  """

  @behaviour AgentYard.Sandboxes.Runner

  @impl true
  def prepare(config) do
    with true <- not is_nil(System.find_executable("docker")),
         {:ok, network_policy_args} <- AgentYard.Sandboxes.NetworkPolicy.prepare(config) do
      {:ok,
       config
       |> Map.put(:sandbox, :docker)
       |> Map.put(:network_policy_args, network_policy_args)}
    else
      false -> {:error, :docker_not_available}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def cleanup(config), do: AgentYard.Sandboxes.NetworkPolicy.cleanup(config)

  @impl true
  def command(config, args) do
    case docker_args(config, args) do
      {:ok, docker_args} ->
        task = Task.async(fn -> System.cmd("docker", docker_args, stderr_to_stdout: true) end)
        {:ok, task.ref}

      {:error, _reason} = error ->
        error
    end
  end

  @impl true
  def port(config, args) do
    with executable when is_binary(executable) <- System.find_executable("docker"),
         {:ok, docker_args} <- docker_args(config, args) do
      {:ok,
       Port.open({:spawn_executable, to_charlist(executable)}, [
         :binary,
         :exit_status,
         {:line, 1_048_576},
         {:args, Enum.map(docker_args, &to_charlist/1)}
       ])}
    else
      nil -> {:error, :docker_not_available}
      {:error, _reason} = error -> error
    end
  rescue
    error in ErlangError -> {:error, error}
  end

  @doc """
  Builds the Docker invocation without starting a container.

  This is public so deployment checks can assert the effective network policy
  without requiring a Docker daemon.
  """
  def command_args(config, args), do: docker_args(config, args)

  defp docker_args(config, args) do
    image = config[:image] || "agentyard/runner:latest"
    workspace = config[:workspace] || File.cwd!()
    cpu = config[:cpus] || 2
    memory = config[:memory] || "2g"
    env = config[:env] || %{}

    with {:ok, network_policy_args} <- network_policy_args(config) do
      {:ok,
       [
         "run",
         "--rm"
         | network_policy_args ++
             [
               "--cpus",
               to_string(cpu),
               "--memory",
               to_string(memory),
               "--cap-drop",
               "ALL",
               "--security-opt",
               "no-new-privileges",
               "--mount",
               "type=bind,src=#{workspace},dst=/workspace",
               "--workdir",
               "/workspace"
             ]
       ]
       |> Kernel.++(Enum.flat_map(env, fn {key, value} -> ["--env", "#{key}=#{value}"] end))
       |> Kernel.++([image | args])}
    end
  end

  defp network_policy_args(%{network_policy_args: args}) when is_list(args), do: {:ok, args}

  defp network_policy_args(config),
    do: AgentYard.Sandboxes.NetworkPolicy.prepare(config)
end
