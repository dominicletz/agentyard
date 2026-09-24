defmodule AgentYard.Accounts.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(owner admin member)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "memberships" do
    field(:role, :string, default: "member")

    belongs_to(:user, AgentYard.Accounts.User)
    belongs_to(:team, AgentYard.Accounts.Team)

    timestamps(type: :utc_datetime_usec)
  end

  def roles, do: @roles

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :team_id, :role])
    |> validate_required([:user_id, :team_id, :role])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:user_id, :team_id])
  end
end
