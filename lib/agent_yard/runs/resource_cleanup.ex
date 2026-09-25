defmodule AgentYard.Runs.ResourceCleanup do
  @moduledoc """
  Best-effort cleanup for per-run sandbox and workspace resources.

  Cleanup is deliberately idempotent: terminal transitions can race with
  adapter callbacks, and removing an already-removed workspace is harmless.
  """

  @doc """
  Invokes the sandbox cleanup hook and removes a managed run workspace.
  """
  @spec cleanup(module() | nil, map()) :: :ok | {:error, term()}
  def cleanup(sandbox, config) do
    results = [
      sandbox_cleanup(sandbox, config),
      workspace_cleanup(config),
      mcp_cleanup(config)
    ]

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp sandbox_cleanup(nil, _config), do: :ok

  defp sandbox_cleanup(sandbox, config) do
    sandbox.cleanup(config)
  rescue
    error -> {:error, {:sandbox_cleanup_failed, error}}
  end

  defp workspace_cleanup(%{workspace_managed?: true, workspace: workspace})
       when is_binary(workspace) do
    case File.rm_rf(workspace) do
      {:ok, _files} -> :ok
      {:error, reason, _file} -> {:error, {:workspace_cleanup_failed, reason}}
    end
  end

  defp workspace_cleanup(_config), do: :ok

  defp mcp_cleanup(%{mcp_config_path: path}) when is_binary(path) do
    case File.rm_rf(Path.dirname(path)) do
      {:ok, _files} -> :ok
      {:error, reason, _file} -> {:error, {:mcp_cleanup_failed, reason}}
    end
  end

  defp mcp_cleanup(_config), do: :ok
end
