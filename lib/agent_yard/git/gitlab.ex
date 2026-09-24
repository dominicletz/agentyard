defmodule AgentYard.Git.GitLab do
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

  defp authenticated_url(%{token: token}, "https://" <> rest),
    do: "https://oauth2:#{token}@#{rest}"

  defp authenticated_url(_config, remote_url), do: remote_url
end
