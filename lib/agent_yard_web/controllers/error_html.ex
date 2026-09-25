defmodule AgentYardWeb.ErrorHTML do
  use AgentYardWeb, :html

  def render(template, _assigns), do: Phoenix.HTML.raw("<h1>#{template}</h1>")
end
