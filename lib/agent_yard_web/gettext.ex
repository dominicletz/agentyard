defmodule AgentYardWeb.Gettext do
  @moduledoc """
  Translation backend for the AgentYard web layer.
  """

  use Gettext.Backend, otp_app: :agentyard
end
