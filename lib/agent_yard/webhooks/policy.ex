defmodule AgentYard.Webhooks.Policy do
  @moduledoc """
  Safety checks for forge-triggered runs.

  Webhook payloads are not an authorization API. The policy only accepts
  explicit write evidence from the event payload and rejects pull requests
  whose source repository cannot be established as trusted. A future forge
  permission lookup can provide a `trusted_workspace`/permission result without
  changing the controller boundary.
  """

  @github_write_associations ~w(OWNER MEMBER COLLABORATOR)

  @doc """
  Checks that the GitHub mention author has repository write access.

  `repository["permissions"]` describes the webhook installation/token, not
  necessarily the person who wrote the comment, so it is deliberately ignored.
  """
  def authorize_github_mention(payload) when is_map(payload) do
    sender = payload["sender"] || %{}
    permissions = sender["permissions"] || %{}

    association =
      sender["author_association"] ||
        get_in(payload, ["comment", "author_association"])

    if truthy?(permissions["push"]) or
         truthy?(permissions["maintain"]) or
         truthy?(permissions["admin"]) or
         String.upcase(to_string(association || "")) in @github_write_associations do
      :ok
    else
      {:error, :mentioner_lacks_write_access}
    end
  end

  def authorize_github_mention(_payload), do: {:error, :mentioner_lacks_write_access}

  @doc """
  Checks the GitLab user's project access level for a write-capable role.
  """
  def authorize_gitlab_mention(params) when is_map(params) do
    user = params["user"] || %{}

    if integer_value(user["access_level"]) >= 30 do
      :ok
    else
      {:error, :mentioner_lacks_write_access}
    end
  end

  def authorize_gitlab_mention(_params), do: {:error, :mentioner_lacks_write_access}

  @doc """
  Rejects GitHub pull requests from forks or without trusted source metadata.

  Issue-comment payloads commonly omit the PR head repository. Such a PR
  cannot safely be cloned by ref in the base repository, so it is rejected
  unless an upstream verifier marks the payload as trusted.
  """
  def reject_github_fork(payload) when is_map(payload) do
    case github_pull_request(payload) do
      nil ->
        :ok

      pull_request ->
        reject_github_pull_request(payload, pull_request)
    end
  end

  def reject_github_fork(_payload), do: :ok

  defp reject_github_pull_request(payload, pull_request) do
    source_repo = get_in(pull_request, ["head", "repo"])

    cond do
      payload["trusted_workspace"] == true ->
        :ok

      fork_repository?(payload, source_repo) ->
        {:error, :fork_pull_request_rejected}

      is_map(source_repo) ->
        :ok

      true ->
        {:error, :untrusted_pull_request_workspace}
    end
  end

  defp fork_repository?(payload, source_repo) when is_map(source_repo) do
    truthy?(source_repo["fork"]) or different_repository?(payload["repository"], source_repo)
  end

  defp fork_repository?(_payload, _source_repo), do: false

  @doc """
  Rejects GitLab merge requests whose source project differs from the target.
  """
  def reject_gitlab_fork(%{"object_attributes" => attributes}) when is_map(attributes) do
    if present?(attributes["source_project_id"]) and
         present?(attributes["target_project_id"]) and
         attributes["source_project_id"] != attributes["target_project_id"] do
      {:error, :fork_merge_request_rejected}
    else
      :ok
    end
  end

  def reject_gitlab_fork(_params), do: :ok

  defp github_pull_request(%{"pull_request" => pull_request}) when is_map(pull_request),
    do: pull_request

  defp github_pull_request(%{"issue" => %{"pull_request" => pull_request}})
       when is_map(pull_request),
       do: pull_request

  defp github_pull_request(_payload), do: nil

  defp different_repository?(base_repo, source_repo)
       when is_map(base_repo) and is_map(source_repo) do
    base = base_repo["full_name"] || base_repo["clone_url"] || base_repo["html_url"]
    source = source_repo["full_name"] || source_repo["clone_url"] || source_repo["html_url"]

    present?(base) and present?(source) and base != source
  end

  defp different_repository?(_base_repo, _source_repo), do: false

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp present?(value), do: value not in [nil, ""]

  defp integer_value(value) when is_integer(value), do: value

  defp integer_value(value) do
    case Integer.parse(to_string(value || "")) do
      {integer, _} -> integer
      :error -> 0
    end
  end
end
