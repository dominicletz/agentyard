defmodule AgentYard.Agents.ACPStubTest do
  use ExUnit.Case, async: true

  alias AgentYard.Agents.ACPStub

  test "emits a visible not-implemented error through normalized events" do
    test_pid = self()
    callback = fn event -> send(test_pid, event) end

    assert {:ok, %{}} = ACPStub.start(%{}, callback)

    assert_receive %AgentYard.Agents.Event{
      type: "status",
      message: "ACP adapter boundary selected"
    }

    assert_receive %AgentYard.Agents.Event{
      type: "error",
      message: "ACP runtime is not implemented"
    }
  end

  test "keeps follow-up explicit until an ACP transport exists" do
    assert {:error, :acp_not_implemented} =
             ACPStub.follow_up(%{}, "continue", fn _event -> :ok end)

    assert :ignore = ACPStub.normalize(%{})
  end
end
