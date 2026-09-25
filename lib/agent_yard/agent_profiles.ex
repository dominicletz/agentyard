defmodule AgentYard.AgentProfiles do
  @moduledoc """
  Context for team-scoped agent profile configuration.
  """

  import Ecto.Query, warn: false
  alias AgentYard.AgentProfiles.Profile
  alias AgentYard.Repo

  def list_for_team(team_id) do
    from(p in Profile, where: p.team_id == ^team_id, order_by: [asc: p.name])
    |> Repo.all()
  end

  def get_for_team!(id, team_id), do: Repo.get_by!(Profile, id: id, team_id: team_id)

  def default_for_team(team_id) do
    from(p in Profile,
      where: p.team_id == ^team_id and p.enabled == true,
      order_by: [asc: p.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def create(team_id, attrs) do
    %Profile{}
    |> Profile.changeset(Map.put(attrs, :team_id, team_id))
    |> Repo.insert()
  end

  def change(%Profile{} = profile, attrs \\ %{}), do: Profile.changeset(profile, attrs)
end
