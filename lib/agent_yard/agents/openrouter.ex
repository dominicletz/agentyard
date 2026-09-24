defmodule AgentYard.Agents.OpenRouter do
  @behaviour AgentYard.Agents.Adapter

  alias AgentYard.Agents.Event

  @impl true
  def prepare(config), do: {:ok, config}

  @impl true
  def start(config, callback) do
    task =
      Task.async(fn ->
        callback.(Event.status("Calling the configured OpenAI-compatible endpoint"))
        request(config, callback)
      end)

    {:ok, %{task: task, config: config, callback: callback}}
  end

  @impl true
  def follow_up(state, prompt, _callback) do
    start(Map.put(state.config, :prompt, prompt), state.callback)
  end

  @impl true
  def cancel(%{task: task}) do
    Task.shutdown(task, :brutal_kill)
    :ok
  end

  @impl true
  def normalize(_payload), do: :ignore

  defp request(config, callback) do
    url = config[:base_url] || "https://openrouter.ai/api/v1/chat/completions"
    key = config[:api_key] || System.get_env("OPENROUTER_API_KEY")

    if is_nil(key) do
      callback.(Event.error("OPENROUTER_API_KEY is not configured"))
      callback.(Event.done())
    else
      body =
        Jason.encode!(%{
          model: config[:model] || "openai/gpt-4o-mini",
          messages: [%{role: "user", content: config[:prompt] || ""}],
          stream: false
        })

      headers = [
        {~c"authorization", to_charlist("Bearer #{key}")},
        {~c"content-type", ~c"application/json"}
      ]

      case :httpc.request(:post, {to_charlist(url), headers, ~c"application/json", body}, [], []) do
        {:ok, {{_, 200, _}, _headers, response}} ->
          with {:ok, decoded} <- Jason.decode(to_string(response)),
               [choice | _] <- decoded["choices"] || [] do
            callback.(Event.assistant_delta(get_in(choice, ["message", "content"]) || ""))
            callback.(Event.usage(decoded["usage"] || %{}))
            callback.(Event.result("OpenRouter request completed"))
            callback.(Event.done())
          else
            _ ->
              callback.(Event.error("OpenRouter returned an unexpected response"))
              callback.(Event.done())
          end

        {:ok, {{_, status, _}, _headers, _response}} ->
          callback.(Event.error("OpenRouter returned HTTP #{status}"))
          callback.(Event.done())

        {:error, reason} ->
          callback.(Event.error("OpenRouter request failed: #{inspect(reason)}"))
          callback.(Event.done())
      end
    end
  end
end
