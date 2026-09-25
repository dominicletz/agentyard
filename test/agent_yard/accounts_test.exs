defmodule AgentYard.AccountsTest do
  use ExUnit.Case, async: true

  alias AgentYard.Accounts.{Membership, Team, User}

  test "registration changeset hashes a password and normalizes email" do
    changeset =
      User.registration_changeset(%User{}, %{
        email: "DEMO@example.com",
        name: "Demo",
        password: "long-enough-password"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :email) == "demo@example.com"
    assert is_binary(Ecto.Changeset.get_change(changeset, :hashed_password))
    refute Ecto.Changeset.get_change(changeset, :password)
  end

  test "team slugs and membership roles are validated" do
    assert Team.slugify("Acme Engineering / Berlin") == "acme-engineering-berlin"

    assert Membership.changeset(%Membership{}, %{
             team_id: Ecto.UUID.generate(),
             user_id: Ecto.UUID.generate(),
             role: "owner"
           }).valid?

    refute Membership.changeset(%Membership{}, %{
             team_id: Ecto.UUID.generate(),
             user_id: Ecto.UUID.generate(),
             role: "viewer"
           }).valid?
  end
end
