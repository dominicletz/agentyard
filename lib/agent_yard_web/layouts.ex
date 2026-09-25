defmodule AgentYardWeb.Layouts do
  use AgentYardWeb, :html

  embed_templates("templates/layouts/*")

  def initials(nil), do: "AY"

  def initials(value) do
    value
    |> to_string()
    |> String.split("@")
    |> hd()
    |> String.split(~r/[^a-zA-Z0-9]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end
end
