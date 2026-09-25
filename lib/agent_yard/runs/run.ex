defmodule AgentYard.Runs.Run do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(queued running succeeded failed cancelled)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "runs" do
    field(:prompt, :string)
    field(:status, :string, default: "queued")
    field(:trigger, :string, default: "ui")
    field(:base_branch, :string, default: "main")
    field(:branch_name, :string)
    field(:adapter, :string)
    field(:auto_pr, :boolean, default: true)
    field(:environment, :string, default: "local")
    field(:issue_url, :string)
    field(:timeout_seconds, :integer, default: 3600)
    field(:max_turns, :integer)
    field(:input_tokens, :integer, default: 0)
    field(:output_tokens, :integer, default: 0)
    field(:cache_tokens, :integer, default: 0)
    field(:cost_usd, :decimal, default: Decimal.new("0"))
    field(:error, :string)
    field(:pr_url, :string)
    field(:merge_request_url, :string)
    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)

    belongs_to(:team, AgentYard.Accounts.Team)
    belongs_to(:user, AgentYard.Accounts.User)
    belongs_to(:session, AgentYard.Runs.Session)
    has_many(:events, AgentYard.Runs.RunEvent)

    timestamps(type: :utc_datetime_usec)
  end

  def statuses, do: @statuses

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :team_id,
      :user_id,
      :session_id,
      :prompt,
      :status,
      :trigger,
      :base_branch,
      :branch_name,
      :adapter,
      :auto_pr,
      :environment,
      :issue_url,
      :timeout_seconds,
      :max_turns,
      :input_tokens,
      :output_tokens,
      :cache_tokens,
      :cost_usd,
      :error,
      :pr_url,
      :merge_request_url,
      :started_at,
      :finished_at
    ])
    |> validate_required([:team_id, :user_id, :session_id, :prompt, :status, :trigger])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:prompt, min: 1, max: 100_000)
    |> validate_inclusion(:environment, ~w(local docker))
    |> validate_number(:timeout_seconds, greater_than: 0)
    |> validate_number(:max_turns, greater_than: 0)
  end
end
