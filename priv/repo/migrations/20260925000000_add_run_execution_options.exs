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
    end
  end
end
