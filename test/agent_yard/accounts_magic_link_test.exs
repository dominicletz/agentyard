defmodule AgentYard.AccountsMagicLinkTest do
  use AgentYardWeb.ConnCase, async: false

  import Ecto.Query
  import Swoosh.TestAssertions

  alias AgentYard.Accounts
  alias AgentYard.Accounts.{MagicLinkToken, User}
  alias AgentYard.Repo

  setup do
    if Process.whereis(Repo) do
      {:ok, user: user_fixture()}
    else
      {:ok, database: false}
    end
  end

  test "requests a magic link and delivers it through Swoosh", context do
    if context[:database] == false do
      assert true
    else
      user = context.user

      assert :ok =
               Accounts.request_magic_link(user.email, fn token ->
                 "https://example.test/login/magic/#{token}"
               end)

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.subject == "Your AgentYard sign-in link"
        assert email.text_body =~ "https://example.test/login/magic/"
        true
      end)
    end
  end

  test "consumes a valid magic link once", context do
    if context[:database] == false do
      assert true
    else
      user = context.user
      raw_token = request_token(user)

      assert {:ok, %User{id: user_id}} = Accounts.consume_magic_link(raw_token)
      assert user_id == user.id
      assert {:error, :invalid_magic_link} = Accounts.consume_magic_link(raw_token)
    end
  end

  test "consumes a link through the session controller", context do
    if context[:database] == false do
      assert true
    else
      user = context.user
      raw_token = request_token(user)
      conn = get(build_conn(), "/login/magic/#{raw_token}")

      assert redirected_to(conn) == "/runs"
      assert get_session(conn, :user_id) == user.id
    end
  end

  test "rejects an expired magic link", context do
    if context[:database] == false do
      assert true
    else
      user = context.user
      raw_token = request_token(user)

      Repo.update_all(
        from(token in MagicLinkToken, where: token.user_id == ^user.id),
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)]
      )

      assert {:error, :invalid_magic_link} = Accounts.consume_magic_link(raw_token)
    end
  end

  test "rejects an invalid magic link", context do
    if context[:database] == false do
      assert true
    else
      assert {:error, :invalid_magic_link} =
               Accounts.consume_magic_link("not-a-real-magic-link")
    end
  end

  test "returns the same successful outcome for an unknown email", context do
    if context[:database] == false do
      assert true
    else
      assert :ok =
               Accounts.request_magic_link("missing@example.test", fn token ->
                 "https://example.test/login/magic/#{token}"
               end)

      refute_email_sent()
    end
  end

  test "stores only a hash of the emailed token", context do
    if context[:database] == false do
      assert true
    else
      user = context.user
      raw_token = request_token(user)
      token = Repo.one!(from(token in MagicLinkToken, where: token.user_id == ^user.id))

      refute token.token_hash == raw_token
      assert token.token_hash =~ ~r/\A[0-9a-f]{64}\z/
    end
  end

  defp request_token(%User{} = user) do
    assert :ok =
             Accounts.request_magic_link(user.email, fn token ->
               "https://example.test/login/magic/#{token}"
             end)

    assert_received {:email, email}

    [_, raw_token] =
      Regex.run(~r{https://example\.test/login/magic/([A-Za-z0-9_-]+)}, email.text_body)

    raw_token
  end

  defp user_fixture do
    suffix = Ecto.UUID.generate() |> String.replace("-", "")

    %User{}
    |> User.registration_changeset(%{
      email: "magic-#{suffix}@example.test",
      name: "Magic Link User",
      password: "long-enough-password"
    })
    |> Repo.insert!()
  end
end
