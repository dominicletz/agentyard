defmodule AgentYard.Sandboxes.NetworkPolicy do
  @moduledoc """
  Resolves Docker network arguments for a run.

  Docker's `bridge` network is not a domain allowlist. When an allowlist is
  present, AgentYard therefore fails closed unless an operator-provided policy
  hook resolves it to an egress-controlled Docker network. The hook may create
  and later remove a per-run network, or delegate to an external firewall/
  proxy.

  A hook module implements `prepare/1` and may implement `cleanup/1`. Both
  receive the complete run sandbox config. `prepare/1` must return
  `{:ok, docker_run_args}` containing a `--network` option.
  """

  @type hook_result :: {:ok, [String.t()]} | {:error, term()}

  @doc """
  Returns the Docker arguments that enforce the configured network policy.
  """
  @spec prepare(map()) :: hook_result()
  def prepare(config) do
    allowlist = normalize_allowlist(config[:network_allowlist])

    if allowlist == [] do
      {:ok, ["--network", configured_network(config)]}
    else
      case configured_hook(config) do
        nil ->
          {:error, {:network_allowlist_requires_hook, allowlist}}

        hook ->
          config
          |> Map.put(:network_allowlist, allowlist)
          |> invoke(hook)
          |> validate_result()
      end
    end
  end

  @doc """
  Gives a configured hook an opportunity to remove per-run network resources.
  """
  @spec cleanup(map()) :: :ok | {:error, term()}
  def cleanup(config) do
    case configured_hook(config) do
      module when is_atom(module) ->
        if function_exported?(module, :cleanup, 1), do: module.cleanup(config), else: :ok

      _hook ->
        :ok
    end
  end

  defp configured_network(%{network: network}) when is_binary(network) and network != "",
    do: network

  defp configured_network(_config), do: "none"

  defp configured_hook(config) do
    config[:network_allowlist_hook] ||
      Application.get_env(:agentyard, :sandbox_network_allowlist_hook)
  end

  defp invoke(config, hook) when is_function(hook, 1), do: hook.(config)

  defp invoke(config, module) when is_atom(module) do
    if function_exported?(module, :prepare, 1) do
      module.prepare(config)
    else
      {:error, {:invalid_network_allowlist_hook, module}}
    end
  end

  defp invoke(config, {module, function}) when is_atom(module) and is_atom(function) do
    if function_exported?(module, function, 1) do
      apply(module, function, [config])
    else
      {:error, {:invalid_network_allowlist_hook, {module, function}}}
    end
  end

  defp invoke(_config, hook), do: {:error, {:invalid_network_allowlist_hook, hook}}

  defp validate_result({:ok, args}) when is_list(args) do
    if Enum.all?(args, &is_binary/1) and "--network" in args do
      {:ok, args}
    else
      {:error, {:invalid_network_policy_args, args}}
    end
  end

  defp validate_result({:error, _reason} = error), do: error
  defp validate_result(other), do: {:error, {:invalid_network_policy_result, other}}

  defp normalize_allowlist(allowlist) when is_list(allowlist) do
    allowlist
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_allowlist(_allowlist), do: []
end
