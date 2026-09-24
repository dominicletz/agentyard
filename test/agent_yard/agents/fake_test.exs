defmodule AgentYard.Agents.FakeTest do
  use ExUnit.Case, async: true

  alias AgentYard.Agents.{Event, Fake}

  test "streams a deterministic normalized script" do
    test_pid = self()

    {:ok, _state} =
      Fake.start(%{prompt: "fix checkout"}, fn event -> send(test_pid, {:event, event}) end)

    events = collect_events([])

    assert Enum.at(events, 0).type == "status"
    assert Enum.any?(events, &(&1.type == "tool_call" and &1.tool == "git"))
    assert Enum.any?(events, &(&1.type == "result" and &1.message == "Demo run completed"))
    assert List.last(events) == Event.done()
  end

  defp collect_events(events) do
    receive do
      {:event, event} -> collect_events(events ++ [event])
    after
      2_000 -> events
    end
  end
end
