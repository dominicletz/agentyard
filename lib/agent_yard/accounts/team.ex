defmodule AgentYard.Accounts.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field(:name, :string)
    field(:slug, :string)

    has_many(:memberships, AgentYard.Accounts.Membership)
    has_many(:users, through: [:memberships, :user])
    has_many(:repositories, AgentYard.Repositories.Repository)
    has_many(:agent_profiles, AgentYard.AgentProfiles.Profile)
    has_many(:sessions, AgentYard.Runs.Session)
    has_many(:runs, AgentYard.Runs.Run)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> update_change(:slug, &slugify/1)
    |> unique_constraint(:slug)
  end

  def slugify(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
