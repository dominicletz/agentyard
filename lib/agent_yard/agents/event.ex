defmodule AgentYard.Agents.Event do
  @moduledoc "The provider-neutral event vocabulary stored in a run timeline."

  @types ~w(status assistant_delta tool_call tool_result usage result error done)

  @enforce_keys [:type]
  defstruct [:type, :text, :tool, :input, :output, :usage, :cost_usd, :message, :raw]

  @type t :: %__MODULE__{
          type: String.t(),
          text: String.t() | nil,
          tool: String.t() | nil,
          input: term(),
          output: term(),
          usage: map() | nil,
          cost_usd: number() | nil,
          message: String.t() | nil,
          raw: map() | nil
        }

  def types, do: @types

  def status(message), do: %__MODULE__{type: "status", message: message}
  def assistant_delta(text), do: %__MODULE__{type: "assistant_delta", text: text}
  def tool_call(tool, input), do: %__MODULE__{type: "tool_call", tool: tool, input: input}
  def tool_result(tool, output), do: %__MODULE__{type: "tool_result", tool: tool, output: output}
  def usage(usage), do: %__MODULE__{type: "usage", usage: usage}
  def result(message), do: %__MODULE__{type: "result", message: message}
  def error(message), do: %__MODULE__{type: "error", message: message}
  def done, do: %__MODULE__{type: "done"}

  def to_payload(%__MODULE__{} = event) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Map.update("raw", nil, &mask_raw/1)
  end

  def from_payload(payload) when is_map(payload) do
    struct(__MODULE__, atomize_known_keys(payload))
  end

  defp atomize_known_keys(payload) do
    key_map = %{
      "type" => :type,
      "text" => :text,
      "tool" => :tool,
      "input" => :input,
      "output" => :output,
      "usage" => :usage,
      "cost_usd" => :cost_usd,
      "message" => :message,
      "raw" => :raw
    }

    Enum.reduce(payload, %{}, fn {key, value}, acc ->
      key = if is_atom(key), do: key, else: Map.get(key_map, key)
      if key, do: Map.put(acc, key, value), else: acc
    end)
  end

  defp mask_raw(nil), do: nil
  defp mask_raw(raw) when is_map(raw), do: Map.drop(raw, ["env", :env, "secret", :secret])
  defp mask_raw(raw), do: raw
end
