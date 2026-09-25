defmodule AgentYard.Sandboxes.Docker do
  @moduledoc """
  Local Docker runner with per-run workspace and resource limits.
  """

  @behaviour AgentYard.Sandboxes.Runner

  @impl true
  def prepare(config) do
    if System.find_executable("docker") do
      {:ok, Map.put(config, :sandbox, :docker)}
    else
      {:error, :docker_not_available}
    end
  end

  @impl true
  def cleanup(_config), do: :ok

  @impl true
  def command(config, args) do
    docker_args = docker_args(config, args)

    task = Task.async(fn -> System.cmd("docker", docker_args, stderr_to_stdout: true) end)
    {:ok, task.ref}
  end

  @impl true
  def port(config, args) do
    {:ok,
     Port.open({:spawn_executable, to_charlist(System.find_executable("docker"))}, [
       :binary,
       :exit_status,
       {:line, 1_048_576},
       {:args, Enum.map(docker_args(config, args), &to_charlist/1)}
     ])}
  rescue
    error in ErlangError -> {:error, error}
  end

  defp docker_args(config, args) do
    image = config[:image] || "agentyard/runner:latest"
    workspace = config[:workspace] || File.cwd!()
    cpu = config[:cpus] || 2
    memory = config[:memory] || "2g"
    env = config[:env] || %{}

    [
      "run",
      "--rm",
      "--network",
      network(config),
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
    |> Kernel.++(Enum.flat_map(env, fn {key, value} -> ["--env", "#{key}=#{value}"] end))
    |> Kernel.++([image | args])
  end

  defp network(%{network: network}) when is_binary(network) and network != "",
    do: network

  defp network(%{network_allowlist: allowlist}) when is_list(allowlist) and allowlist != [],
    do: "bridge"

  defp network(_config), do: "none"
end
