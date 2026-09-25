defmodule AgentYardWeb.SessionController do
  use AgentYardWeb, :controller

  alias AgentYard.Accounts
  alias AgentYardWeb.UserAuth

  def new(conn, _params) do
    render_auth(
      conn,
      "Sign in to AgentYard",
      "/login",
      "Sign in",
      "/register",
      "Create an account",
      magic_link: true
    )
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Email or password is incorrect.")
        |> render_auth(
          "Sign in to AgentYard",
          "/login",
          "Sign in",
          "/register",
          "Create an account"
        )
    end
  end

  def request_magic_link(conn, %{"email" => email}) do
    Accounts.request_magic_link(email, &magic_link_url/1)
    redirect(conn, to: "/login/magic/sent")
  end

  def request_magic_link(conn, _params), do: redirect(conn, to: "/login/magic/sent")

  def magic_link_sent(conn, _params), do: render_magic_link_sent(conn)

  def consume_magic_link(conn, %{"token" => raw_token}) do
    case Accounts.consume_magic_link(raw_token) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "That sign-in link is invalid or has expired.")
        |> redirect(to: "/login")
    end
  end

  def register(conn, _params) do
    render_auth(
      conn,
      "Create your AgentYard account",
      "/register",
      "Create account",
      "/login",
      "Sign in",
      []
    )
  end

  def do_register(conn, %{"email" => email, "name" => name, "password" => password}) do
    case Accounts.register_user(%{email: email, name: name, password: password}) do
      {:ok, user} ->
        case Accounts.create_team_for_user(user, %{name: "#{name}'s team", slug: name}) do
          {:ok, _team} -> UserAuth.log_in_user(conn, user)
          {:error, _} -> retry_register(conn, "Could not create the team.")
        end

      {:error, changeset} ->
        retry_register(conn, format_errors(changeset))
    end
  end

  def delete(conn, _params), do: UserAuth.log_out_user(conn)

  defp retry_register(conn, message) do
    conn
    |> put_flash(:error, message)
    |> render_auth(
      "Create your AgentYard account",
      "/register",
      "Create account",
      "/login",
      "Sign in",
      []
    )
  end

  defp render_auth(conn, title, action, submit, link, link_text, opts \\ []) do
    csrf = Plug.CSRFProtection.get_csrf_token()

    fields =
      if action == "/register" do
        ~s(<label>Name<input name="name" required autocomplete="name" /></label>)
      else
        ""
      end

    magic_link_form =
      if Keyword.get(opts, :magic_link, false) do
        """
        <div class="auth-divider"><span>or</span></div>
        <form method="post" action="/login/magic" class="auth-form">
          <input type="hidden" name="_csrf_token" value="#{csrf}" />
          <label>Email<input name="email" type="email" required autocomplete="email" /></label>
          <button class="button button-secondary" type="submit">Email me a magic link</button>
        </form>
        """
      else
        ""
      end

    body = """
        <form method="post" action="#{action}" class="auth-form">
          <input type="hidden" name="_csrf_token" value="#{csrf}" />
          #{fields}
          <label>Email<input name="email" type="email" required autocomplete="email" /></label>
          <label>Password<input name="password" type="password" required minlength="8" autocomplete="current-password" /></label>
          <button class="button button-primary" type="submit">#{submit}</button>
        </form>
        #{magic_link_form}
        <a class="auth-link" href="#{link}">#{link_text}</a>
    """

    render_auth_page(conn, title, body)
  end

  defp render_magic_link_sent(conn) do
    body = """
        <p>Check your email for a one-time sign-in link.</p>
        <p class="muted">If an account exists for that address, the message should arrive shortly. The link expires in #{Accounts.magic_link_ttl_minutes()} minutes.</p>
        <a class="auth-link" href="/login">Back to sign in</a>
    """

    render_auth_page(conn, "Check your email", body)
  end

  defp render_auth_page(conn, title, body) do
    error = Phoenix.Flash.get(conn.assigns[:flash] || %{}, :error)

    html = """
    <main class="auth-page">
      <div class="auth-card">
        <a class="brand auth-brand" href="/"><span class="brand-mark">AY</span><strong>AgentYard</strong></a>
        <h1>#{title}</h1>
        <p class="muted">The open-source control plane for team coding agents.</p>
        #{if error, do: ~s(<p class="flash flash-error">#{error}</p>), else: ""}
        #{body}
      </div>
    </main>
    """

    Phoenix.Controller.html(conn, html)
  end

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _}} -> "#{field} #{message}" end)
  end

  defp magic_link_url(raw_token) do
    AgentYardWeb.Endpoint.url() <> "/login/magic/" <> URI.encode(raw_token)
  end
end
