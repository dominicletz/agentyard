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
    image = config[:image] || "agentyard/runner:latest"
    workspace = config[:workspace] || File.cwd!()
    cpu = config[:cpus] || 2
    memory = config[:memory] || "2g"
    env = config[:env] || %{}

    docker_args =
      [
        "run",
        "--rm",
        "--network",
        config[:network] || "none",
        "--cpus",
        to_string(cpu),
        "--memory",
        to_string(memory),
        "--mount",
        "type=bind,src=#{workspace},dst=/workspace",
        "--workdir",
        "/workspace"
      ] ++
        Enum.flat_map(env, fn {key, value} -> ["--env", "#{key}=#{value}"] end) ++
        [image | args]

    task = Task.async(fn -> System.cmd("docker", docker_args, stderr_to_stdout: true) end)
    {:ok, task.ref}
  end
end
