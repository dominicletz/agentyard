defmodule AgentYard.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:password, :string, virtual: true)
    field(:hashed_password, :string)
    field(:confirmed_at, :utc_datetime_usec)

    has_many(:memberships, AgentYard.Accounts.Membership)
    has_many(:api_tokens, AgentYard.Accounts.ApiToken)

    timestamps(type: :utc_datetime_usec)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :name, :password])
    |> update_change(:email, &String.downcase/1)
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+$/)
    |> validate_length(:password, min: 8, max: 72)
    |> put_hashed_password()
    |> unique_constraint(:email)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :confirmed_at])
    |> update_change(:email, &String.downcase/1)
    |> validate_required([:email, :name])
    |> unique_constraint(:email)
  end

  def valid_password?(%__MODULE__{hashed_password: hash}, password)
      when is_binary(hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _), do: false

  defp put_hashed_password(changeset) do
    if password = get_change(changeset, :password) do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
