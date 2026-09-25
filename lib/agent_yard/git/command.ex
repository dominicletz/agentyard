defmodule AgentYard.Git.Command do
  @moduledoc false

  def run(args, opts \\ []) do
    case System.cmd("git", args, Keyword.merge([stderr_to_stdout: true], opts)) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, status} -> {:error, {:git_failed, status, String.trim(output)}}
    end
  rescue
    error in ErlangError -> {:error, error}
  end

  def clone(remote_url, ref, workspace, env \\ []) do
    with :ok <- File.mkdir_p(Path.dirname(workspace)),
         {:ok, _} <-
           run(["clone", remote_url, workspace], env: env),
         {:ok, _} <- run(["-C", workspace, "checkout", ref], env: env) do
      {:ok, workspace}
    end
  end

  def branch(workspace, branch), do: run(["-C", workspace, "switch", "-c", branch])

  def commit_push(workspace, branch, message) do
    with {:ok, _} <- run(["-C", workspace, "add", "--all"]),
         {:ok, _} <- run(["-C", workspace, "commit", "-m", message]),
         {:ok, _} <- run(["-C", workspace, "push", "--set-upstream", "origin", branch]) do
      :ok
    end
  end
end
