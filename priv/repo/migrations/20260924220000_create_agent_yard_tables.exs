defmodule AgentYard.Repo.Migrations.CreateAgentYardTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :name, :string, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])

    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:teams, [:slug])

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:memberships, [:user_id, :team_id])

    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :token_hash, :string, null: false
      add :last_used_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_tokens, [:token_hash])

    create table(:repositories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :forge, :string, null: false, default: "github"
      add :remote_url, :string, null: false
      add :default_branch, :string, null: false, default: "main"
      add :description, :text
      add :environment_image, :string
      timestamps(type: :utc_datetime_usec)
    end

    create index(:repositories, [:team_id])

    create table(:agent_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :provider, :string, null: false, default: "fake"
      add :model, :string
      add :instructions, :text
      add :permission_mode, :string, null: false, default: "accept_edits"
      add :budget_usd, :decimal, precision: 12, scale: 6, default: 5
      add :enabled, :boolean, null: false, default: true
      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_profiles, [:team_id])

    create table(:secrets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :encrypted_value, :binary, null: false
      add :scope, :string, null: false, default: "team"
      timestamps(type: :utc_datetime_usec)
    end

    create index(:secrets, [:team_id])
    create unique_index(:secrets, [:team_id, :repository_id, :name])

    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_profile_id, references(:agent_profiles, type: :binary_id, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :status, :string, null: false, default: "active"
      add :branch_name, :string
      timestamps(type: :utc_datetime_usec)
    end

    create index(:sessions, [:team_id])

    create table(:runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :prompt, :text, null: false
      add :status, :string, null: false, default: "queued"
      add :trigger, :string, null: false, default: "ui"
      add :base_branch, :string, null: false, default: "main"
      add :branch_name, :string
      add :adapter, :string
      add :input_tokens, :integer, null: false, default: 0
      add :output_tokens, :integer, null: false, default: 0
      add :cache_tokens, :integer, null: false, default: 0
      add :cost_usd, :decimal, precision: 12, scale: 6, null: false, default: 0
      add :error, :text
      add :pr_url, :string
      add :merge_request_url, :string
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create index(:runs, [:team_id, :status])
    create index(:runs, [:session_id])

    create table(:run_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:runs, type: :binary_id, on_delete: :delete_all), null: false
      add :sequence, :integer, null: false
      add :kind, :string, null: false
      add :payload, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:run_events, [:run_id, :sequence])
    create index(:run_events, [:run_id, :inserted_at])
  end
end
