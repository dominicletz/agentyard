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

  @doc """
  Replaces secret values anywhere in an event before it is broadcast or stored.

  Secret values are treated as opaque binaries so values containing punctuation
  or regular-expression characters cannot break redaction.
  """
  def mask(%__MODULE__{} = event, secrets) when is_map(secrets) do
    values =
      secrets
      |> Map.values()
      |> Enum.filter(&(is_binary(&1) and byte_size(&1) > 0))

    event
    |> Map.from_struct()
    |> mask_term(values)
    |> then(&struct(__MODULE__, &1))
  end

  def to_payload(%__MODULE__{} = event) do
    event
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if is_nil(value) do
        acc
      else
        Map.put(acc, Atom.to_string(key), mask_raw(value))
      end
    end)
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

  defp mask_term(value, []), do: value
  defp mask_term(value, secrets) when is_binary(value) do
    Enum.reduce(secrets, value, fn secret, value ->
      :binary.replace(value, secret, "[REDACTED]", [:global])
    end)
  end

  defp mask_term(value, secrets) when is_map(value) do
    Map.new(value, fn {key, nested} -> {key, mask_term(nested, secrets)} end)
  end

  defp mask_term(value, secrets) when is_list(value),
    do: Enum.map(value, &mask_term(&1, secrets))

  defp mask_term(value, secrets) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map(&mask_term(&1, secrets)) |> List.to_tuple()

  defp mask_term(value, _secrets), do: value
end
