defmodule AgentYardWeb.Api.RepositoryController do
  use AgentYardWeb, :controller

  alias AgentYard.Repositories

  def index(%{assigns: %{team: team}} = conn, _params) do
    repositories =
      team.id
      |> Repositories.list_for_team()
      |> Enum.map(fn repository ->
        %{
          id: repository.id,
          name: repository.name,
          forge: repository.forge,
          remote_url: repository.remote_url,
          default_branch: repository.default_branch,
          description: repository.description,
          environment_image: repository.environment_image
        }
      end)

    json(conn, %{data: repositories})
  end
end
