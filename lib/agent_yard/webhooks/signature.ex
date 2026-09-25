defmodule AgentYard.Webhooks.Signature do
  @moduledoc """
  Constant-time verification helpers for forge webhook requests.
  """

  def github?(body, "sha256=" <> provided, secret) when is_binary(secret) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, body)
      |> Base.encode16(case: :lower)

    secure_compare(expected, String.downcase(provided))
  end

  def github?(_body, _signature, _secret), do: false

  def gitlab?(provided, expected) when is_binary(provided) and is_binary(expected),
    do: secure_compare(provided, expected)

  def gitlab?(_provided, _expected), do: false

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_compare(_left, _right), do: false
end
