defmodule AgentYard.Repo.Migrations.AddRunExecutionOptions do
  use Ecto.Migration

  def change do
    alter table(:agent_profiles) do
      add :base_url, :string
    end

    alter table(:runs) do
      add :auto_pr, :boolean, null: false, default: true
      add :environment, :string, null: false, default: "local"
      add :issue_url, :string
      add :timeout_seconds, :integer, null: false, default: 3600
      add :max_turns, :integer
    end

    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :subject_type, :string, null: false
      add :subject_id, :string
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:audit_events, [:team_id, :inserted_at])
  end
end
