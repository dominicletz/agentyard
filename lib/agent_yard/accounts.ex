defmodule AgentYard.Accounts do
  @moduledoc """
  Accounts, teams, membership and API-token boundaries.
  """

  import Ecto.Query, warn: false
  alias AgentYard.Accounts.{ApiToken, MagicLinkEmail, MagicLinkToken, Membership, Team, User}
  alias AgentYard.Repo
  require Logger

  @magic_link_ttl_seconds 30 * 60
  @magic_link_request_interval_seconds 60

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) do
    case get_user_by_email(email) do
      %User{} = user ->
        if User.valid_password?(user, password),
          do: {:ok, user},
          else: {:error, :invalid_credentials}

      nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def magic_link_ttl_minutes, do: div(@magic_link_ttl_seconds, 60)

  def request_magic_link(email, link_builder)
      when is_binary(email) and is_function(link_builder, 1) do
    case get_user_by_email(String.trim(email)) do
      %User{} = user -> maybe_send_magic_link(user, link_builder)
      nil -> :ok
    end
  end

  def request_magic_link(_email, _link_builder), do: :ok

  def consume_magic_link(raw_token) when is_binary(raw_token) and raw_token != "" do
    token_hash = hash_token(raw_token)
    now = DateTime.utc_now()

    Repo.transaction(fn -> consume_magic_link_transaction(token_hash, now) end)
  end

  def consume_magic_link(_raw_token), do: {:error, :invalid_magic_link}

  def create_team(attrs) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  def create_team_for_user(%User{} = user, attrs) do
    Repo.transaction(fn ->
      {:ok, team} = create_team(attrs)

      {:ok, _membership} =
        %Membership{}
        |> Membership.changeset(%{team_id: team.id, user_id: user.id, role: "owner"})
        |> Repo.insert()

      team
    end)
  end

  def add_member(%Team{} = team, %User{} = user, role \\ "member") do
    %Membership{}
    |> Membership.changeset(%{team_id: team.id, user_id: user.id, role: role})
    |> Repo.insert()
  end

  def membership_for(%User{id: user_id}, %Team{id: team_id}) do
    Repo.get_by(Membership, user_id: user_id, team_id: team_id)
  end

  def list_members(%Team{id: team_id}) do
    from(m in Membership,
      join: u in assoc(m, :user),
      where: m.team_id == ^team_id,
      order_by: [asc: u.email],
      select: %{id: m.id, role: m.role, email: u.email, name: u.name}
    )
    |> Repo.all()
  end

  def authorize(%User{} = user, %Team{} = team, allowed_roles) when is_list(allowed_roles) do
    case membership_for(user, team) do
      %Membership{role: role} ->
        if role in allowed_roles, do: :ok, else: {:error, :forbidden}

      _ ->
        {:error, :forbidden}
    end
  end

  def team_for_user(%User{id: user_id}) do
    from(m in Membership,
      join: t in assoc(m, :team),
      where: m.user_id == ^user_id,
      order_by: [asc: t.name],
      limit: 1,
      select: t
    )
    |> Repo.one()
  end

  def team_with_name(%User{id: user_id}) do
    from(u in User,
      join: m in assoc(u, :memberships),
      join: t in assoc(m, :team),
      where: u.id == ^user_id,
      select: t.name,
      limit: 1
    )
    |> Repo.one()
  end

  def get_team(id), do: Repo.get(Team, id)

  def first_member(%Team{id: team_id}) do
    from(m in Membership,
      join: u in assoc(m, :user),
      where: m.team_id == ^team_id,
      order_by: [asc: m.inserted_at],
      limit: 1,
      select: u
    )
    |> Repo.one()
  end

  def create_api_token(%User{} = user, name \\ "default") do
    raw = "ay_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    attrs = %{
      user_id: user.id,
      name: name,
      token_hash: hash_token(raw)
    }

    with {:ok, token} <- %ApiToken{} |> ApiToken.changeset(attrs) |> Repo.insert() do
      {:ok, raw, token}
    end
  end

  def get_user_by_api_token(raw) when is_binary(raw) do
    hash = hash_token(raw)

    from(t in ApiToken,
      join: u in assoc(t, :user),
      where: t.token_hash == ^hash,
      preload: [user: u]
    )
    |> Repo.one()
    |> case do
      %ApiToken{} = token ->
        _ = Repo.update(Ecto.Changeset.change(token, last_used_at: DateTime.utc_now()))
        token.user

      nil ->
        nil
    end
  end

  def demo_user do
    get_user_by_email("demo@agentyard.local")
  end

  defp consume_magic_link_transaction(token_hash, now) do
    token = find_magic_link_token(token_hash, now)

    with %MagicLinkToken{} = token <- token,
         {:ok, _token} <- Repo.update(Ecto.Changeset.change(token, consumed_at: now)) do
      get_user!(token.user_id)
    else
      _ -> Repo.rollback(:invalid_magic_link)
    end
  end

  defp find_magic_link_token(token_hash, now) do
    from(t in MagicLinkToken,
      where:
        t.token_hash == ^token_hash and is_nil(t.consumed_at) and
          t.expires_at > ^now,
      lock: "FOR UPDATE"
    )
    |> Repo.one()
  end

  defp maybe_send_magic_link(user, link_builder) do
    now = DateTime.utc_now()

    if magic_link_requested_recently?(user, now) do
      :ok
    else
      raw_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      attrs = %{
        user_id: user.id,
        token_hash: hash_token(raw_token),
        expires_at: DateTime.add(now, @magic_link_ttl_seconds, :second)
      }

      with {:ok, _token} <-
             %MagicLinkToken{} |> MagicLinkToken.changeset(attrs) |> Repo.insert(),
           {:ok, _result} <-
             MagicLinkEmail.new(user, link_builder.(raw_token))
             |> AgentYard.Mailer.deliver() do
        :ok
      else
        {:error, reason} ->
          Logger.error("magic-link delivery failed: #{inspect(reason)}")
          :ok
      end
    end
  end

  defp magic_link_requested_recently?(%User{id: user_id}, now) do
    cutoff = DateTime.add(now, -@magic_link_request_interval_seconds, :second)

    from(t in MagicLinkToken,
      where:
        t.user_id == ^user_id and is_nil(t.consumed_at) and
          t.inserted_at > ^cutoff and t.expires_at > ^now,
      select: t.id,
      limit: 1
    )
    |> Repo.exists?()
  end

  defp hash_token(raw), do: :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
end
