defmodule AgentYard.Repositories do
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

  def create(team_id, attrs) do
    %Repository{}
    |> Repository.changeset(Map.put(attrs, :team_id, team_id))
    |> Repo.insert()
  end

  def change(%Repository{} = repository, attrs \\ %{}) do
    Repository.changeset(repository, attrs)
  end
end
