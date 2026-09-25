defmodule AgentYard.AgentProfiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ~w(fake claude_code cursor_cli openrouter)
  @permissions ~w(ask accept_edits plan bypass)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_profiles" do
    field(:name, :string)
    field(:provider, :string, default: "fake")
    field(:model, :string)
    field(:base_url, :string)
    field(:mcp_servers, :map, default: %{})
    field(:instructions, :string)
    field(:permission_mode, :string, default: "accept_edits")
    field(:budget_usd, :decimal)
    field(:enabled, :boolean, default: true)

    belongs_to(:team, AgentYard.Accounts.Team)
    has_many(:sessions, AgentYard.Runs.Session, foreign_key: :agent_profile_id)

    timestamps(type: :utc_datetime_usec)
  end

  def providers, do: @providers
  def permissions, do: @permissions

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :team_id,
      :name,
      :provider,
      :model,
      :base_url,
      :mcp_servers,
      :instructions,
      :permission_mode,
      :budget_usd,
      :enabled
    ])
    |> validate_required([:team_id, :name, :provider, :permission_mode])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:permission_mode, @permissions)
    |> validate_number(:budget_usd, greater_than: 0)
  end
end
