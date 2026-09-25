defmodule AgentYard.Repo.Migrations.CreateMagicLinkTokens do
  use Ecto.Migration

  def change do
    create table(:magic_link_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:magic_link_tokens, [:token_hash])
    create index(:magic_link_tokens, [:user_id, :expires_at])
  end
end
