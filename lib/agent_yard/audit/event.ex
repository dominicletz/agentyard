defmodule AgentYard.Audit.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_events" do
    field(:action, :string)
    field(:subject_type, :string)
    field(:subject_id, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:team, AgentYard.Accounts.Team)
    belongs_to(:user, AgentYard.Accounts.User)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:team_id, :user_id, :action, :subject_type, :subject_id, :metadata])
    |> validate_required([:team_id, :action, :subject_type, :metadata])
  end
end
