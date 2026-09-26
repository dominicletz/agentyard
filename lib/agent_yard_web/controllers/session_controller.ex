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
    render_auth_page(conn, %{
      page_title: title,
      title: title,
      form_action: action,
      submit_label: submit,
      alternate_path: link,
      alternate_label: link_text,
      show_name: action == "/register",
      password_autocomplete:
        if(action == "/register", do: "new-password", else: "current-password"),
      show_magic_link: Keyword.get(opts, :magic_link, false),
      magic_link_sent: false
    })
  end

  defp render_magic_link_sent(conn) do
    render_auth_page(conn, %{
      page_title: "Check your email",
      title: "Check your email",
      magic_link_ttl_minutes: Accounts.magic_link_ttl_minutes(),
      magic_link_sent: true,
      show_name: false,
      show_magic_link: false,
      form_action: nil,
      submit_label: nil,
      alternate_path: nil,
      alternate_label: nil
    })
  end

  defp render_auth_page(conn, assigns) do
    assigns =
      assigns
      |> Map.put(:auth_error, Phoenix.Flash.get(conn.assigns[:flash] || %{}, :error))
      |> Map.put(:csrf_token, Plug.CSRFProtection.get_csrf_token())

    render(conn, :auth, assigns)
  end

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _}} -> "#{field} #{message}" end)
  end

  defp magic_link_url(raw_token) do
    AgentYardWeb.Endpoint.url() <> "/login/magic/" <> URI.encode(raw_token)
  end
end
