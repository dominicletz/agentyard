defmodule AgentYard.Security.SecretBox do
  @moduledoc """
  Small AES-256-GCM envelope used for write-only team secrets.

  The instance key is supplied through `AGENTYARD_SECRET_KEY` in production.
  Values are never included in changesets, event payloads or rendered views.
  """

  @aad "agentyard-secret-v1"

  def encrypt(value) when is_binary(value) do
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, value, @aad, true)
    :erlang.term_to_binary({iv, tag, ciphertext}, [:compressed])
  end

  def decrypt(envelope) when is_binary(envelope) do
    with {iv, tag, ciphertext} <- :erlang.binary_to_term(envelope, [:safe]),
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, ciphertext, @aad, tag, false) do
      plaintext
    else
      _ -> {:error, :invalid_secret}
    end
  rescue
    ArgumentError -> {:error, :invalid_secret}
  end

  def mask(value) when is_binary(value) do
    if byte_size(value) == 0, do: "", else: "[REDACTED]"
  end

  def mask(_), do: "[REDACTED]"

  defp key do
    secret = Application.get_env(:agentyard, :secret_key, "development-secret-change-me")
    :crypto.hash(:sha256, secret)
  end
end
