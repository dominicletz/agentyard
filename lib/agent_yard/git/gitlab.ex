defmodule AgentYard.Git.GitLab do
  @moduledoc """
  GitLab provider for authenticated repository and merge request operations.
  """

  @behaviour AgentYard.Git.Provider

  alias AgentYard.Git.{Command, ForgeHTTP}

  @impl true
  def clone(config, remote_url, ref, workspace) do
    Command.clone(authenticated_url(config, remote_url), ref, workspace)
  end

  @impl true
  def create_branch(_config, workspace, branch), do: Command.branch(workspace, branch)

  @impl true
  def commit_and_push(_config, workspace, branch, message),
    do: Command.commit_push(workspace, branch, message)

  @impl true
  def open_change(config, branch, title, body) do
    project = URI.encode(config.project_id || ForgeHTTP.slug(config.remote_url))
    base_url = String.trim_trailing(config.base_url || "https://gitlab.com", "/")

    with {:ok, response} <-
           ForgeHTTP.request(
             :post,
             "#{base_url}/api/v4/projects/#{project}/merge_requests",
             config.token,
             %{
               title: title,
               source_branch: branch,
               target_branch: config.base_branch || "main",
               description: body
             }
           ) do
      {:ok, %{url: response["web_url"], number: response["iid"]}}
    end
  end

  @impl true
  def post_comment(config, source_url, body) do
    with {:ok, kind, iid} <- source_reference(source_url) do
      base_url = String.trim_trailing(config.base_url || "https://gitlab.com", "/")
      path = if kind == "issues", do: "issues", else: "merge_requests"

      case ForgeHTTP.request(
             :post,
             "#{base_url}/api/v4/projects/#{URI.encode(config.project_id)}/#{path}/#{iid}/notes",
             config.token,
             %{body: body}
           ) do
        {:ok, _response} -> :ok
        error -> error
      end
    end
  end

  defp authenticated_url(%{token: token}, "https://" <> rest),
    do: "https://oauth2:#{token}@#{rest}"

  defp authenticated_url(_config, remote_url), do: remote_url

  defp source_reference(url) when is_binary(url) do
    case URI.parse(url).path do
      path when is_binary(path) ->
        case Regex.run(~r{/-/(issues|merge_requests)/(\d+)$}, path) do
          [_, kind, iid] -> {:ok, kind, iid}
          _ -> {:error, :invalid_gitlab_source_url}
        end

      _ ->
        {:error, :invalid_gitlab_source_url}
    end
  end

  defp source_reference(_url), do: {:error, :invalid_gitlab_source_url}
end
