defmodule AgentYard.Runs.RunEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "run_events" do
    field(:sequence, :integer)
    field(:kind, :string)
    field(:payload, :map, default: %{})

    belongs_to(:run, AgentYard.Runs.Run)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:run_id, :sequence, :kind, :payload])
    |> validate_required([:run_id, :sequence, :kind, :payload])
    |> unique_constraint([:run_id, :sequence])
  end
end
