defmodule AgentYard.Runs.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field(:title, :string)
    field(:status, :string, default: "active")
    field(:branch_name, :string)

    belongs_to(:team, AgentYard.Accounts.Team)
    belongs_to(:repository, AgentYard.Repositories.Repository)
    belongs_to(:agent_profile, AgentYard.AgentProfiles.Profile)
    has_many(:runs, AgentYard.Runs.Run)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:team_id, :repository_id, :agent_profile_id, :title, :status, :branch_name])
    |> validate_required([
      :team_id,
      :repository_id,
      :agent_profile_id,
      :title,
      :status
    ])
    |> validate_inclusion(:status, ~w(active archived))
  end
end
