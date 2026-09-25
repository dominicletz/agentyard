defmodule AgentYard.Git.GitHub do
  @moduledoc """
  GitHub provider for authenticated repository and pull request operations.
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
    with {:ok, response} <-
           ForgeHTTP.request(
             :post,
             "https://api.github.com/repos/#{ForgeHTTP.slug(config.remote_url)}/pulls",
             config.token,
             %{title: title, head: branch, base: config.base_branch || "main", body: body}
           ) do
      {:ok, %{url: response["html_url"], number: response["number"]}}
    end
  end

  @impl true
  def post_comment(config, source_url, body) do
    with {:ok, number} <- issue_number(source_url),
         {:ok, _response} <-
           ForgeHTTP.request(
             :post,
             "https://api.github.com/repos/#{ForgeHTTP.slug(config.remote_url)}/issues/#{number}/comments",
             config.token,
             %{body: body}
           ) do
      :ok
    end
  end

  defp authenticated_url(%{token: token}, "https://" <> rest),
    do: "https://x-access-token:#{token}@#{rest}"

  defp authenticated_url(_config, remote_url), do: remote_url

  defp issue_number(url) when is_binary(url) do
    case URI.parse(url).path do
      path when is_binary(path) ->
        case Regex.run(~r{/(?:issues|pull)/(\d+)$}, path) do
          [_, number] -> {:ok, number}
          _ -> {:error, :invalid_github_source_url}
        end

      _ ->
        {:error, :invalid_github_source_url}
    end
  end

  defp issue_number(_url), do: {:error, :invalid_github_source_url}
end
