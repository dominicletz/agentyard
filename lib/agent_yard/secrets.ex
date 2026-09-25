defmodule AgentYard.Secrets do
  @moduledoc """
  Context for encrypted team and repository secrets.
  """

  import Ecto.Query, warn: false
  alias AgentYard.Repo
  alias AgentYard.Secrets.Secret
  alias AgentYard.Security.SecretBox

  def put(team_id, attrs) do
    value = Map.fetch!(attrs, :value)

    secret_attrs =
      attrs
      |> Map.delete(:value)
      |> Map.put(:team_id, team_id)
      |> Map.put(:encrypted_value, SecretBox.encrypt(value))

    %Secret{}
    |> Secret.changeset(secret_attrs)
    |> Repo.insert()
  end

  def list_for_team(team_id) do
    from(s in Secret,
      where: s.team_id == ^team_id,
      order_by: [asc: s.name],
      select: %{id: s.id, name: s.name, scope: s.scope, repository_id: s.repository_id}
    )
    |> Repo.all()
  end

  def values_for_run(team_id, repository_id) do
    from(s in Secret,
      where:
        s.team_id == ^team_id and
          (s.scope == "team" or (s.scope == "repository" and s.repository_id == ^repository_id))
    )
    |> Repo.all()
    |> Map.new(fn secret -> {secret.name, SecretBox.decrypt(secret.encrypted_value)} end)
    |> Enum.reduce(%{}, fn
      {name, value}, values when is_binary(value) -> Map.put(values, name, value)
      {_name, _invalid}, values -> values
    end)
  end
end
