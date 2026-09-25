defmodule AgentYardWeb.WebhookController do
  use AgentYardWeb, :controller

  alias AgentYard.{Accounts, AgentProfiles, Repositories, Runs}
  alias AgentYard.Webhooks.Signature

  @mention ~r/@agentyard\b/i
  @labels ~w(agent agentyard)

  def github(conn, params) do
    body = conn.private[:agentyard_raw_body] || Jason.encode!(params)
    signature = List.first(get_req_header(conn, "x-hub-signature-256"))

    secret =
      System.get_env("GITHUB_WEBHOOK_SECRET") ||
        Application.get_env(:agentyard, :github_webhook_secret)

    if Signature.github?(body, signature, secret) do
      dispatch(conn, "github", get_req_header(conn, "x-github-event") |> List.first(), params)
    else
      unauthorized(conn)
    end
  end

  def gitlab(conn, params) do
    token = List.first(get_req_header(conn, "x-gitlab-token"))

    secret =
      System.get_env("GITLAB_WEBHOOK_SECRET") ||
        Application.get_env(:agentyard, :gitlab_webhook_secret)

    if Signature.gitlab?(token, secret) do
      dispatch(conn, "gitlab", nil, params)
    else
      unauthorized(conn)
    end
  end

  defp dispatch(conn, forge, event_name, params) do
    case run_request(forge, event_name, params) do
      :ignore ->
        json(conn, %{status: "ignored"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})

      {:ok, attrs} ->
        with {:ok, run} <- create_webhook_run(attrs) do
          conn
          |> put_status(:accepted)
          |> json(%{data: %{run_id: run.id, status: run.status}})
        else
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: inspect(reason)})
        end
    end
  end

  defp create_webhook_run(attrs) do
    with repository when not is_nil(repository) <-
           Repositories.find_for_webhook(attrs.repository),
         team when not is_nil(team) <- Accounts.get_team(repository.team_id),
         user when not is_nil(user) <- Accounts.first_member(team),
         profile when not is_nil(profile) <- AgentProfiles.default_for_team(team.id),
         {:ok, run} <-
           Runs.create_run(user, team, %{
             repository_id: repository.id,
             agent_profile_id: profile.id,
             prompt: attrs.prompt,
             trigger: attrs.trigger,
             base_branch: attrs.base_branch || repository.default_branch,
             branch_name: attrs[:branch_name],
             issue_url: attrs[:issue_url],
             auto_pr: Map.get(attrs, :auto_pr, true)
           }),
         {:ok, _job} <- Runs.start_run(run) do
      {:ok, run}
    else
      nil -> {:error, :webhook_repository_not_connected}
      false -> {:error, :webhook_team_not_configured}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_request("github", event_name, params) do
    repository = params["repository"] || %{}
    sender = params["sender"] || %{}

    cond do
      event_name == "issue_comment" ->
        comment = get_in(params, ["comment", "body"]) || ""
        issue = params["issue"] || %{}

        with :ok <- permitted?(sender, repository),
             :ok <- reject_fork(issue),
             true <- mention?(comment) do
          {:ok,
           %{
             repository: repository,
             prompt: strip_mention(comment),
             trigger: "github_mention",
             issue_url: issue["html_url"],
             base_branch: get_in(issue, ["pull_request", "base", "ref"]),
             branch_name: get_in(issue, ["pull_request", "head", "ref"]),
             auto_pr: is_nil(issue["pull_request"])
           }}
        else
          false -> :ignore
          {:error, reason} -> {:error, reason}
        end

      event_name in ["issues", "pull_request"] and params["action"] == "labeled" ->
        label = get_in(params, ["label", "name"]) || ""

        with :ok <- permitted?(sender, repository),
             true <- label in @labels do
          {:ok,
           %{
             repository: repository,
             prompt: "Address the issue associated with the #{label} label.",
             trigger: "github_label",
             issue_url: get_in(params, ["issue", "html_url"]) || params["html_url"],
             base_branch: get_in(params, ["pull_request", "base", "ref"]),
             branch_name: get_in(params, ["pull_request", "head", "ref"]),
             auto_pr: is_nil(params["pull_request"])
           }}
        else
          false -> :ignore
          {:error, reason} -> {:error, reason}
        end

      true ->
        :ignore
    end
  end

  defp run_request("gitlab", _event_name, params) do
    project = params["project"] || %{}
    user = params["user"] || %{}
    attributes = params["object_attributes"] || %{}
    note = attributes["note"] || ""
    labels = params["labels"] || []
    label_names = Enum.map(labels, & &1["title"])
    merge_request = params["object_kind"] == "merge_request"

    cond do
      mention?(note) ->
        with :ok <- gitlab_permitted?(user),
             :ok <- reject_gitlab_fork(params) do
          {:ok,
           %{
             repository: project,
             prompt: strip_mention(note),
             trigger: "gitlab_mention",
             issue_url: attributes["url"],
             base_branch: attributes["target_branch"],
             branch_name: attributes["source_branch"],
             auto_pr: not merge_request
           }}
        else
          {:error, reason} -> {:error, reason}
        end

      Enum.any?(label_names, &(&1 in @labels)) ->
        with :ok <- gitlab_permitted?(user),
             :ok <- reject_gitlab_fork(params) do
          {:ok,
           %{
             repository: project,
             prompt: "Address the issue associated with the agent label.",
             trigger: "gitlab_label",
             issue_url: attributes["url"],
             base_branch: attributes["target_branch"],
             branch_name: attributes["source_branch"],
             auto_pr: not merge_request
           }}
        else
          {:error, reason} -> {:error, reason}
        end

      true ->
        :ignore
    end
  end

  defp permitted?(sender, repository) do
    permissions = sender["permissions"] || repository["permissions"] || %{}

    if permissions["push"] || permissions["maintain"] || permissions["admin"],
      do: :ok,
      else: {:error, :mentioner_lacks_write_access}
  end

  defp gitlab_permitted?(user) do
    if (user["access_level"] || 0) >= 30,
      do: :ok,
      else: {:error, :mentioner_lacks_write_access}
  end

  defp reject_fork(%{"pull_request" => %{"head" => %{"repo" => %{"fork" => true}}}}),
    do: {:error, :fork_pull_request_rejected}

  defp reject_fork(_issue), do: :ok

  defp reject_gitlab_fork(%{"object_attributes" => attributes} = params) do
    if attributes["source_project_id"] && attributes["target_project_id"] &&
         attributes["source_project_id"] != attributes["target_project_id"],
       do: {:error, :fork_merge_request_rejected},
       else: :ok
  end

  defp reject_gitlab_fork(_params), do: :ok

  defp mention?(text), do: Regex.match?(@mention, text)

  defp strip_mention(text) do
    Regex.replace(@mention, text, "")
    |> String.trim()
    |> case do
      "" -> "Please inspect and address the reported issue."
      prompt -> prompt
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid webhook signature"})
  end
end
