defmodule AgentYard.Webhooks.PolicyTest do
  use ExUnit.Case, async: true

  alias AgentYard.Webhooks.Policy

  test "accepts a GitHub mention from an explicit write-capable sender" do
    assert :ok =
             Policy.authorize_github_mention(%{
               "sender" => %{"permissions" => %{"push" => true}},
               "repository" => %{"permissions" => %{"push" => false}}
             })

    assert :ok =
             Policy.authorize_github_mention(%{
               "sender" => %{"author_association" => "MEMBER"}
             })
  end

  test "does not mistake installation permissions for mentioner permissions" do
    assert {:error, :mentioner_lacks_write_access} =
             Policy.authorize_github_mention(%{
               "sender" => %{"login" => "read-only-user"},
               "repository" => %{"permissions" => %{"push" => true}}
             })
  end

  test "rejects GitHub fork pull requests" do
    payload = %{
      "repository" => %{"full_name" => "acme/app"},
      "pull_request" => %{
        "head" => %{"repo" => %{"full_name" => "contributor/app", "fork" => true}}
      }
    }

    assert {:error, :fork_pull_request_rejected} = Policy.reject_github_fork(payload)
  end

  test "rejects a pull request without trusted source metadata" do
    payload = %{
      "repository" => %{"full_name" => "acme/app"},
      "issue" => %{"pull_request" => %{"url" => "https://api.github.test/pulls/1"}}
    }

    assert {:error, :untrusted_pull_request_workspace} = Policy.reject_github_fork(payload)

    assert :ok = Policy.reject_github_fork(Map.put(payload, "trusted_workspace", true))
  end

  test "accepts a same-repository GitHub pull request with source metadata" do
    payload = %{
      "repository" => %{"full_name" => "acme/app"},
      "pull_request" => %{
        "head" => %{"repo" => %{"full_name" => "acme/app", "fork" => false}}
      }
    }

    assert :ok = Policy.reject_github_fork(payload)
  end

  test "requires a GitLab write-capable access level" do
    assert :ok = Policy.authorize_gitlab_mention(%{"user" => %{"access_level" => 40}})

    assert {:error, :mentioner_lacks_write_access} =
             Policy.authorize_gitlab_mention(%{"user" => %{"access_level" => 20}})
  end

  test "rejects GitLab merge requests from another project" do
    assert {:error, :fork_merge_request_rejected} =
             Policy.reject_gitlab_fork(%{
               "object_attributes" => %{
                 "source_project_id" => 2,
                 "target_project_id" => 1
               }
             })

    assert :ok =
             Policy.reject_gitlab_fork(%{
               "object_attributes" => %{
                 "source_project_id" => 1,
                 "target_project_id" => 1
               }
             })
  end
end
