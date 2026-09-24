defmodule AgentYard.Repositories.Repository do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "repositories" do
    field(:name, :string)
    field(:forge, :string, default: "github")
    field(:remote_url, :string)
    field(:default_branch, :string, default: "main")
    field(:description, :string)
    field(:environment_image, :string)

    belongs_to(:team, AgentYard.Accounts.Team)
    has_many(:sessions, AgentYard.Runs.Session)
    has_many(:secrets, AgentYard.Secrets.Secret)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [
      :team_id,
      :name,
      :forge,
      :remote_url,
      :default_branch,
      :description,
      :environment_image
    ])
    |> validate_required([:team_id, :name, :forge, :remote_url, :default_branch])
    |> validate_inclusion(:forge, ~w(github gitlab))
  end
end
