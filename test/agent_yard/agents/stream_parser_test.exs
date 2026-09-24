defmodule AgentYard.Agents.StreamParserTest do
  use ExUnit.Case, async: true

  alias AgentYard.Agents.StreamParser

  test "normalizes Claude Code stream-json fixtures" do
    events =
      "test/fixtures/claude-stream.jsonl"
      |> File.stream!()
      |> Enum.map(&StreamParser.parse_line(&1, :claude_code))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, event} -> event end)

    assert Enum.map(events, & &1.type) == [
             "assistant_delta",
             "tool_call",
             "tool_result",
             "result"
           ]

    assert hd(events).text == "I will inspect the checkout code."
    assert Enum.at(events, 1).tool == "Bash"
    assert Enum.at(events, 3).usage["input_tokens"] == 120
    assert Enum.at(events, 3).cost_usd == 0.034
  end

  test "normalizes Cursor CLI messages and ignores lifecycle noise" do
    events =
      "test/fixtures/cursor-stream.jsonl"
      |> File.stream!()
      |> Enum.map(&StreamParser.parse_line(&1, :cursor_cli))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, event} -> event end)

    assert Enum.map(events, & &1.type) == [
             "assistant_delta",
             "tool_call",
             "tool_result",
             "result",
             "done"
           ]

    assert Enum.at(events, 1).input["path"] == "lib/example.ex"
    assert Enum.at(events, 3).usage["cache_tokens"] == 4
  end

  test "returns malformed JSON as an explicit parser error" do
    assert {:error, {:invalid_json, _}} = StreamParser.parse_line("{not json")
  end
end
