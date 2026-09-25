defmodule AgentYard.Accounts.MagicLinkEmail do
  @moduledoc """
  Swoosh email for passwordless AgentYard sign-in.
  """

  import Swoosh.Email

  alias AgentYard.Accounts.User

  @subject "Your AgentYard sign-in link"

  def new(%User{email: email}, link) when is_binary(link) do
    minutes = AgentYard.Accounts.magic_link_ttl_minutes()

    text = """
    Sign in to AgentYard:

    #{link}

    This one-time link expires in #{minutes} minutes.
    If you did not request this email, you can safely ignore it.
    """

    html = """
    <p>Sign in to AgentYard:</p>
    <p><a href="#{link}">Continue to AgentYard</a></p>
    <p>This one-time link expires in #{minutes} minutes.</p>
    <p>If you did not request this email, you can safely ignore it.</p>
    """

    Swoosh.Email.new()
    |> to(email)
    |> from(Application.get_env(:agentyard, :mailer_from, {"AgentYard", "no-reply@localhost"}))
    |> subject(@subject)
    |> text_body(text)
    |> html_body(html)
  end
end
