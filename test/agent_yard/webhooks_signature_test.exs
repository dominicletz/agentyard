defmodule AgentYard.Webhooks.SignatureTest do
  use ExUnit.Case, async: true

  alias AgentYard.Webhooks.Signature

  test "verifies GitHub sha256 signatures" do
    body = ~s({"action":"opened"})
    secret = "webhook-secret"

    digest =
      :crypto.mac(:hmac, :sha256, secret, body)
      |> Base.encode16(case: :lower)

    assert Signature.github?(body, "sha256=" <> digest, secret)
    assert Signature.github?(body, "sha256=" <> String.upcase(digest), secret)
    refute Signature.github?(body, "sha256=bad", secret)
    refute Signature.github?(body, digest, secret)
    refute Signature.github?(body, "sha1=" <> digest, secret)
    refute Signature.github?(body, "sha256=" <> digest, nil)
  end

  test "verifies GitLab tokens without accepting a different length" do
    assert Signature.gitlab?("webhook-secret", "webhook-secret")
    refute Signature.gitlab?("wrong", "webhook-secret")
    refute Signature.gitlab?("webhook-secret-extra", "webhook-secret")
    refute Signature.gitlab?("webhook-secret", nil)
  end
end
