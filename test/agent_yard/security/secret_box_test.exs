defmodule AgentYard.Security.SecretBoxTest do
  use ExUnit.Case, async: true

  alias AgentYard.Security.SecretBox

  test "encrypts and decrypts with authenticated encryption" do
    ciphertext = SecretBox.encrypt("super-secret")

    assert ciphertext != "super-secret"
    assert SecretBox.decrypt(ciphertext) == "super-secret"
    assert SecretBox.mask("super-secret") == "[REDACTED]"
  end

  test "tampering fails closed" do
    ciphertext = SecretBox.encrypt("super-secret")
    <<first, rest::binary>> = ciphertext

    assert SecretBox.decrypt(<<Bitwise.bxor(first, 1), rest::binary>>) ==
             {:error, :invalid_secret}
  end
end
