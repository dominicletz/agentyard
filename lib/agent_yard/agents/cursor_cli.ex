defmodule AgentYard.Agents.CursorCLI do
  @moduledoc """
  Cursor CLI adapter supporting both current executable names.
  """

  @behaviour AgentYard.Agents.Adapter

  alias AgentYard.Agents.{CLI, StreamParser}

  @impl true
  def prepare(config), do: CLI.prepare(config)

  @impl true
  def start(config, callback),
    do: CLI.start(config, callback, :cursor_cli, ["cursor-agent", "agent"])

  @impl true
  def follow_up(state, prompt, _callback), do: CLI.follow_up(state, prompt)

  @impl true
  def cancel(state), do: CLI.cancel(state)

  @impl true
  def normalize(payload), do: StreamParser.normalize(payload, :cursor_cli)
end
