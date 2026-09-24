defmodule AgentYard.Secrets.Secret do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "secrets" do
    field(:name, :string)
    field(:encrypted_value, :binary)
    field(:scope, :string, default: "team")

    belongs_to(:team, AgentYard.Accounts.Team)
    belongs_to(:repository, AgentYard.Repositories.Repository)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:team_id, :repository_id, :name, :encrypted_value, :scope])
    |> validate_required([:team_id, :name, :encrypted_value, :scope])
    |> validate_inclusion(:scope, ~w(team repository))
    |> unique_constraint([:team_id, :repository_id, :name])
  end
end
