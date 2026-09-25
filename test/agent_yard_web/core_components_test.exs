defmodule AgentYardWeb.CoreComponentsTest do
  @moduledoc """
  Coverage for the small formatting helpers shared by the web UI.
  """

  use ExUnit.Case, async: true

  alias AgentYardWeb.CoreComponents

  test "formats money with stable currency precision" do
    assert CoreComponents.money(Decimal.new("5")) == "5.00"
    assert CoreComponents.money(Decimal.new("0.04")) == "0.04"
    assert CoreComponents.money(Decimal.new("0.001")) == "0.0010"
  end

  test "keeps text payloads literal and pretty-prints structured payloads" do
    text = "On branch agent/fake-demo\nworking tree clean"

    assert CoreComponents.format_payload(text) == text
    assert CoreComponents.format_payload(%{"path" => "lib/example.ex"}) =~ "lib/example.ex"
  end
end
