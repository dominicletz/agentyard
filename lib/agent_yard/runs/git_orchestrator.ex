defmodule AgentYard.Runs.GitOrchestrator do
  @moduledoc """
  Prepares an isolated repository workspace and optionally publishes its result.

  Fake runs intentionally use a local empty repository. This keeps the seeded
  demo deterministic while still exercising the same branch/workspace path as
  real adapters. Real adapters clone the configured ref before they start.
  """

  alias AgentYard.Agents.Event
  alias AgentYard.Git.{Command, GitHub, GitLab}
  alias AgentYard.Runs.Run

  @github_token_keys ~w(GITHUB_TOKEN GH_TOKEN)
  @gitlab_token_keys ~w(GITLAB_TOKEN)

  def prepare(%Run{} = run, config) do
    repository = run.session.repository
    provider = config[:git_provider] || provider_for(repository.forge)
    workspace = config[:workspace] || workspace_path(run, config)
    forge_config = forge_config(repository, run, config)

    with :ok <- File.mkdir_p(workspace),
         {:ok, events} <- clone_or_initialize(run, repository, provider, forge_config, workspace),
         {:ok, _} <- configure_identity(workspace),
         {:ok, branch} <- provider.create_branch(forge_config, workspace, run.branch_name) do
      {:ok,
       Map.merge(config, %{
         workspace: workspace,
         git_provider: provider,
         forge_config: forge_config,
         forge_token: forge_config[:token],
         git_prepared: true,
         branch: branch
       }), events ++ [Event.status("Workspace ready on #{run.branch_name}")]
      }
    end
  end

  def finalize(%Run{auto_pr: false}, _config),
    do: {:ok, nil, [Event.status("Auto PR/MR is disabled for this run")]}

  def finalize(%Run{} = run, %{forge_token: nil}),
    do:
      {:ok, nil,
       [
         Event.status(
           "Auto PR/MR skipped: no #{token_name(run.session.repository.forge)} configured"
         )
       ]}

  def finalize(%Run{} = run, %{git_prepared: false}),
    do: {:ok, nil, [Event.status("Auto PR/MR skipped: workspace was not prepared")]}

  def finalize(%Run{} = run, config) do
    with {:ok, status} <- Command.run(["-C", config.workspace, "status", "--porcelain"]) do
      if String.trim(status) == "" do
        {:ok, nil, [Event.status("No workspace changes; skipped PR/MR creation")]}
      else
        title = run.session.title || "AgentYard run"
        body = result_body(run)

        with :ok <-
               config.git_provider.commit_and_push(
                 config.forge_config,
                 config.workspace,
                 run.branch_name,
                 title
               ),
             {:ok, change} <-
               config.git_provider.open_change(
                 config.forge_config,
                 run.branch_name,
                 title,
                 body
               ) do
          {:ok, change, [Event.status("Opened #{change_label(run.session.repository.forge)}")]}
        end
      end
    end
  end

  def provider_for("gitlab"), do: GitLab
  def provider_for(_forge), do: GitHub

  def token_name("gitlab"), do: "GITLAB_TOKEN"
  def token_name(_forge), do: "GITHUB_TOKEN"

  defp clone_or_initialize(
         %Run{adapter: "fake"},
         _repository,
         _provider,
         forge_config,
         workspace
       ) do
    with {:ok, _} <- Command.run(["init", "-b", forge_config.base_branch, workspace]),
         {:ok, _} <- Command.run(["-C", workspace, "commit", "--allow-empty", "-m", "AgentYard workspace"]) do
      {:ok, [Event.status("Fake adapter: using an isolated local workspace (clone skipped)")]}
    else
      {:error, reason} -> {:error, {:workspace_init_failed, reason}}
    end
  end

  defp clone_or_initialize(
         %Run{} = run,
         repository,
         provider,
         forge_config,
         workspace
       ) do
    case provider.clone(forge_config, repository.remote_url, run.base_branch, workspace) do
      {:ok, _workspace} ->
        {:ok, [Event.status("Cloned #{repository.name} at #{run.base_branch}")]}

      {:error, reason} ->
        {:error, {:clone_failed, reason}}
    end
  end

  defp configure_identity(workspace) do
    with {:ok, _} <- Command.run(["-C", workspace, "config", "user.name", "AgentYard"]),
         {:ok, _} <- Command.run(["-C", workspace, "config", "user.email", "agent@agentyard.local"]) do
      {:ok, workspace}
    end
  end

  defp forge_config(repository, run, config) do
    env = config[:env] || %{}
    token = token_for(repository.forge, env)

    %{
      remote_url: repository.remote_url,
      base_branch: run.base_branch,
      project_id: repository.name,
      token: token
    }
  end

  defp token_for("gitlab", env), do: env_value(env, @gitlab_token_keys)
  defp token_for(_forge, env), do: env_value(env, @github_token_keys)

  defp env_value(env, keys) do
    Enum.find_value(keys, fn key ->
      Enum.find_value(env, fn {name, value} ->
        if String.upcase(to_string(name)) == key and is_binary(value), do: value
      end)
    end)
  end

  defp workspace_path(run, config) do
    root = config[:workspace_root] || Path.join(System.tmp_dir!(), "agentyard-runs")
    Path.join(root, to_string(run.id))
  end

  defp result_body(run) do
    [
      "AgentYard completed this run.",
      "",
      "Prompt: #{run.prompt}",
      if(run.issue_url, do: "Source: #{run.issue_url}", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp change_label("gitlab"), do: "merge request"
  defp change_label(_forge), do: "pull request"
end
