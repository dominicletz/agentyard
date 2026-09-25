defmodule AgentYard.Repo.Migrations.AddMcpServersToProfiles do
  use Ecto.Migration

  def change do
    alter table(:agent_profiles) do
      add :mcp_servers, :map, null: false, default: %{}
    end
  end
end
