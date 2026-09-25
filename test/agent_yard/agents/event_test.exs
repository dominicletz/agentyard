defmodule AgentYard.Agents.EventTest do
  use ExUnit.Case, async: true

  alias AgentYard.Agents.Event

  test "masks secret values in text and nested tool payloads" do
    event = %Event{
      type: "tool_result",
      output: %{"stdout" => "token=top-secret", "nested" => ["top-secret"]}
    }

    masked = Event.mask(event, %{"API_TOKEN" => "top-secret"})

    assert masked.output == %{"stdout" => "token=[REDACTED]", "nested" => ["[REDACTED]"]}
    refute inspect(masked) =~ "top-secret"
  end

  test "does not turn empty secrets into redaction markers" do
    event = Event.assistant_delta("nothing to hide")
    assert Event.mask(event, %{"EMPTY" => ""}) == event
  end
end
