defmodule AgentYard.Sandboxes.DockerTest do
  use ExUnit.Case, async: true

  alias AgentYard.Sandboxes.{Docker, NetworkPolicy}

  test "uses a deny-all network when no allowlist is configured" do
    assert {:ok, ["--network", "none"]} =
             NetworkPolicy.prepare(%{network_allowlist: [], network: "none"})

    assert {:ok, args} =
             Docker.command_args(
               %{workspace: "/tmp/run", image: "runner:test", network_allowlist: []},
               ["echo", "ok"]
             )

    assert Enum.chunk_every(args, 2, 1, :discard) |> Enum.any?(&(&1 == ["--network", "none"]))
    refute "bridge" in args
  end

  test "fails closed instead of treating an allowlist as unrestricted bridge access" do
    assert {:error, {:network_allowlist_requires_hook, ["api.example.test"]}} =
             NetworkPolicy.prepare(%{network_allowlist: ["api.example.test"]})
  end

  test "uses the explicit allowlist policy hook and forwards its Docker args" do
    hook = fn config ->
      assert config.network_allowlist == ["api.example.test"]
      {:ok, ["--network", "agentyard-egress-run", "--label", "egress=api.example.test"]}
    end

    config = %{
      workspace: "/tmp/run",
      image: "runner:test",
      network_allowlist: ["api.example.test"],
      network_allowlist_hook: hook
    }

    assert {:ok, args} = Docker.command_args(config, ["echo", "ok"])
    assert "--network" in args
    assert "agentyard-egress-run" in args
    assert "egress=api.example.test" in args
  end

  test "rejects hooks that do not specify a Docker network" do
    assert {:error, {:invalid_network_policy_args, ["--dns", "127.0.0.1"]}} =
             NetworkPolicy.prepare(%{
               network_allowlist: ["api.example.test"],
               network_allowlist_hook: fn _config -> {:ok, ["--dns", "127.0.0.1"]} end
             })
  end
end
