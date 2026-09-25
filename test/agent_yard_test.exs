defmodule AgentYardTest do
  use ExUnit.Case
  doctest AgentYard

  test "greets the world" do
    assert AgentYard.hello() == :world
  end
end
