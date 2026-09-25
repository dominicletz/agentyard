defmodule AgentYard.Agents.ClaudeCode do
  @moduledoc """
  Claude Code CLI adapter using Claude's stream-json output.
  """

  @behaviour AgentYard.Agents.Adapter

  alias AgentYard.Agents.{CLI, StreamParser}

  @impl true
  def prepare(config), do: CLI.prepare(config)

  @impl true
  def start(config, callback), do: CLI.start(config, callback, :claude_code, ["claude"])

  @impl true
  def follow_up(state, prompt, _callback) do
    CLI.follow_up(state, prompt)
  end

  @impl true
  def cancel(state), do: CLI.cancel(state)

  @impl true
  def normalize(payload), do: StreamParser.normalize(payload, :claude_code)
end
