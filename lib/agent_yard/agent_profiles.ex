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
    |> Profile.changeset(attrs |> decode_mcp_servers() |> Map.put(:team_id, team_id))
    |> Repo.insert()
  end

  def change(%Profile{} = profile, attrs \\ %{}), do: Profile.changeset(profile, attrs)

  defp decode_mcp_servers(attrs) do
    value = Map.get(attrs, :mcp_servers) || Map.get(attrs, "mcp_servers")

    case value do
      value when is_map(value) ->
        attrs

      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, decoded} when is_map(decoded) -> Map.put(attrs, :mcp_servers, decoded)
          _ -> attrs
        end

      _ ->
        attrs
    end
  end
end
