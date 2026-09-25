defmodule AgentYard.Audit do
  @moduledoc """
  Small, append-only audit boundary for team-visible mutations.
  """

  alias AgentYard.Audit.Event
  alias AgentYard.Repo

  def log(team_id, user_id, action, subject_type, subject_id, metadata \\ %{}) do
    %Event{}
    |> Event.changeset(%{
      team_id: team_id,
      user_id: user_id,
      action: action,
      subject_type: subject_type,
      subject_id: subject_id,
      metadata: metadata
    })
    |> Repo.insert()
  end
end
