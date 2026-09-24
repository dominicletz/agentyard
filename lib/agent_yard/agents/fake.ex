defmodule AgentYard.Agents.Fake do
  @behaviour AgentYard.Agents.Adapter

  alias AgentYard.Agents.{Event, StreamParser}

  @impl true
  def prepare(config), do: {:ok, config}

  @impl true
  def start(config, callback) do
    prompt = config[:prompt] || config["prompt"] || "the requested change"
    pid = spawn(fn -> run_script(prompt, callback) end)
    {:ok, %{worker: pid}}
  end

  @impl true
  def follow_up(state, prompt, callback) do
    pid =
      spawn(fn ->
        callback.(Event.status("Reading the follow-up…"))
        Process.sleep(35)
        callback.(Event.assistant_delta("I incorporated your follow-up: #{prompt}"))
        Process.sleep(35)
        callback.(Event.result("Follow-up complete"))
        callback.(Event.done())
      end)

    {:ok, Map.put(state, :worker, pid)}
  end

  @impl true
  def cancel(%{worker: pid}) when is_pid(pid) do
    Process.exit(pid, :kill)
    :ok
  end

  def cancel(_), do: :ok

  @impl true
  def normalize(payload), do: StreamParser.normalize(payload, :fake)

  defp run_script(prompt, callback) do
    callback.(Event.status("Creating an isolated workspace"))
    Process.sleep(35)
    callback.(Event.status("Inspecting the repository"))
    Process.sleep(35)
    callback.(Event.tool_call("git", "status --short"))
    Process.sleep(35)
    callback.(Event.tool_result("git", "On branch agent/fake-demo\nworking tree clean"))
    Process.sleep(35)
    callback.(Event.assistant_delta("I’m working on: #{prompt}"))
    Process.sleep(35)
    callback.(Event.tool_call("edit", "lib/example.ex"))
    Process.sleep(35)
    callback.(Event.tool_result("edit", "Applied the requested change"))
    Process.sleep(35)
    callback.(Event.assistant_delta("The change is ready for review."))
    Process.sleep(35)
    callback.(Event.usage(%{"input_tokens" => 420, "output_tokens" => 180, "cache_tokens" => 0}))
    callback.(%Event{type: "result", message: "Demo run completed", cost_usd: 0.04})
    callback.(Event.done())
  end
end
