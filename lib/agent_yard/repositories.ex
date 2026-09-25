defmodule AgentYard.Repositories do
  @moduledoc """
  Context for team-scoped repository connections.
  """

  import Ecto.Query, warn: false
  alias AgentYard.Repo
  alias AgentYard.Repositories.Repository

  def list_for_team(team_id) do
    from(r in Repository, where: r.team_id == ^team_id, order_by: [asc: r.name])
    |> Repo.all()
  end

  def get_for_team!(id, team_id) do
    Repo.get_by!(Repository, id: id, team_id: team_id)
  end

  def find_for_webhook(repository_payload) when is_map(repository_payload) do
    full_name =
      repository_payload["full_name"] || repository_payload["path_with_namespace"]

    clone_url =
      repository_payload["clone_url"] ||
        repository_payload["git_http_url"] ||
        repository_payload["http_url_to_repo"]

    html_url = repository_payload["html_url"] || repository_payload["web_url"]

    from(r in Repository,
      where:
        (not is_nil(^full_name) and r.name == ^full_name) or
          (not is_nil(^clone_url) and r.remote_url == ^clone_url) or
          (not is_nil(^html_url) and r.remote_url == ^html_url),
      limit: 1
    )
    |> Repo.one()
  end

  def create(team_id, attrs) do
    %Repository{}
    |> Repository.changeset(Map.put(attrs, :team_id, team_id))
    |> Repo.insert()
  end

  def change(%Repository{} = repository, attrs \\ %{}) do
    Repository.changeset(repository, attrs)
  end
end
