defmodule AgentYard.Agents.StreamParser do
  @moduledoc """
  Normalizes the line-delimited JSON emitted by Claude Code and Cursor CLI.
  Unknown lifecycle messages are ignored so CLI upgrades do not break a run.
  """

  alias AgentYard.Agents.Event

  def parse_line(line, provider \\ :claude_code)

  def parse_line(line, provider) when is_binary(line) do
    case Jason.decode(String.trim(line)) do
      {:ok, payload} when is_map(payload) -> normalize(payload, provider)
      {:ok, _} -> :ignore
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  def normalize(payload, provider \\ :claude_code)

  def normalize(%{"type" => "assistant", "message" => message}, provider) when is_map(message) do
    normalize_message_content(message["content"], provider)
  end

  def normalize(%{"type" => "user", "message" => message}, provider) when is_map(message) do
    normalize_message_content(message["content"], provider)
  end

  def normalize(%{"type" => "message", "content" => content}, provider) do
    normalize_message_content(content, provider)
  end

  def normalize(%{"type" => "content_block_delta", "delta" => delta}, _provider)
      when is_map(delta) do
    if delta["type"] in ["text_delta", "text"] and is_binary(delta["text"]) do
      {:ok, Event.assistant_delta(delta["text"])}
    else
      :ignore
    end
  end

  def normalize(%{"type" => "tool_call"} = payload, _provider) do
    {:ok,
     Event.tool_call(payload["name"] || "tool", payload["arguments"] || payload["input"] || %{})}
  end

  def normalize(%{"type" => "tool_use", "name" => name, "input" => input}, _provider) do
    {:ok, Event.tool_call(name, input)}
  end

  def normalize(%{"type" => "tool_result"} = payload, _provider) do
    {:ok,
     Event.tool_result(
       payload["name"] || payload["tool_use_id"] || "tool",
       payload["output"] || payload["content"]
     )}
  end

  def normalize(%{"type" => "result"} = payload, _provider) do
    usage = payload["usage"] || %{}

    {:ok,
     %Event{
       type: "result",
       message: payload["result"] || payload["message"],
       usage: normalize_usage(usage),
       cost_usd: payload["total_cost_usd"] || payload["cost_usd"],
       raw: Map.take(payload, ["subtype", "duration_ms"])
     }}
  end

  def normalize(%{"type" => "error"} = payload, _provider) do
    {:ok, Event.error(payload["error"] || payload["message"] || "Agent returned an error")}
  end

  def normalize(%{"type" => "done"}, _provider), do: {:ok, Event.done()}

  def normalize(%{"type" => "status", "message" => message}, _provider),
    do: {:ok, Event.status(message)}

  def normalize(_, _provider), do: :ignore

  defp normalize_message_content(content, provider) when is_list(content) do
    content
    |> Enum.map(&normalize_content_block(&1, provider))
    |> Enum.find(:ignore, &match?({:ok, _}, &1))
  end

  defp normalize_message_content(content, _provider) when is_binary(content) do
    {:ok, Event.assistant_delta(content)}
  end

  defp normalize_message_content(_, _provider), do: :ignore

  defp normalize_content_block(%{"type" => "text", "text" => text}, _provider)
       when is_binary(text),
       do: {:ok, Event.assistant_delta(text)}

  defp normalize_content_block(
         %{"type" => "tool_use", "name" => name, "input" => input},
         _provider
       ),
       do: {:ok, Event.tool_call(name, input)}

  defp normalize_content_block(%{"type" => "tool_result", "content" => output}, _provider),
    do: {:ok, Event.tool_result("tool", output)}

  defp normalize_content_block(_, _provider), do: :ignore

  defp normalize_usage(usage) do
    %{
      "input_tokens" => usage["input_tokens"] || usage["prompt_tokens"] || 0,
      "output_tokens" => usage["output_tokens"] || usage["completion_tokens"] || 0,
      "cache_tokens" => usage["cache_read_input_tokens"] || usage["cached_tokens"] || 0
    }
  end
end
