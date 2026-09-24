defmodule AgentYardWeb.Api.OpenAPIController do
  use AgentYardWeb, :controller

  def show(conn, _params) do
    path = Application.app_dir(:agentyard, "priv/static/openapi.yaml")
    send_download(conn, {:file, path}, filename: "openapi.yaml", content_type: "text/yaml")
  end
end
