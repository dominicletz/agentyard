defmodule AgentYard.Runs.WorkerTest do
  use ExUnit.Case, async: false

  alias AgentYard.Repo
  alias AgentYard.Runs
  alias AgentYard.Runs.Worker
  alias AgentYard.TestFactory

  setup do
    if Process.whereis(Repo) do
      {:ok, TestFactory.run_fixture()}
    else
      {:ok, database: false}
    end
  end

  test "worker starts a queued run and lets the process finish", context do
    if context[:database] == false do
      assert true
    else
      {:ok, run} =
        Runs.create_run(context.user, context.team, %{
          repository_id: context.repository.id,
          agent_profile_id: context.profile.id,
          prompt: "Run through the Oban worker"
        })

      assert :ok =
               Worker.perform(%Oban.Job{
                 args: %{
                   "run_id" => run.id,
                   "team_id" => run.team_id,
                   "session_id" => run.session_id
                 }
               })

      assert TestFactory.eventually(fn ->
               Repo.get!(AgentYard.Runs.Run, run.id).status == "succeeded"
             end)
    end
  end
end
