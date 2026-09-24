defmodule AgentYard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        repo_child(),
        pubsub_child(),
        registry_child(),
        run_supervisor_child(),
        oban_child(),
        endpoint_child()
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: AgentYard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repo_child do
    if Application.get_env(:agentyard, :start_repo, true) do
      AgentYard.Repo
    end
  end

  defp pubsub_child, do: {Phoenix.PubSub, name: AgentYard.PubSub}

  defp registry_child, do: {Registry, keys: :unique, name: AgentYard.Runs.Registry}

  defp run_supervisor_child do
    {DynamicSupervisor, strategy: :one_for_one, name: AgentYard.Runs.Supervisor}
  end

  defp oban_child do
    if Application.get_env(:agentyard, :start_repo, true) do
      {Oban, Application.get_env(:agentyard, Oban, queues: [runs: 10], plugins: [])}
    end
  end

  defp endpoint_child, do: AgentYardWeb.Endpoint
end
