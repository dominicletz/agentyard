defmodule AgentYard.Agents.OpenRouter do
  @moduledoc """
  Adapter for OpenAI-compatible chat completion endpoints.
  """

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

    api_key =
      config[:api_key] ||
        get_in(config, [:env, "OPENROUTER_API_KEY"]) ||
        get_in(config, [:env, "OPENAI_API_KEY"]) ||
        System.get_env("OPENROUTER_API_KEY") ||
        System.get_env("OPENAI_API_KEY")

    case api_key do
      nil -> fail(callback, "OPENROUTER_API_KEY is not configured")
      key -> request_with_key(config, callback, url, key)
    end
  end

  defp request_with_key(config, callback, url, key) do
    body =
      Jason.encode!(%{
        model: config[:model] || "openai/gpt-4o-mini",
        messages: messages(config),
        stream: false
      })

    headers = [
      {~c"authorization", to_charlist("Bearer #{key}")},
      {~c"content-type", ~c"application/json"}
    ]

    case :httpc.request(:post, {to_charlist(url), headers, ~c"application/json", body}, [], []) do
      {:ok, {{_, 200, _}, _headers, response}} ->
        handle_response(response, callback)

      {:ok, {{_, status, _}, _headers, _response}} ->
        fail(callback, "OpenRouter returned HTTP #{status}")

      {:error, reason} ->
        fail(callback, "OpenRouter request failed: #{inspect(reason)}")
    end
  end

  defp handle_response(response, callback) do
    case Jason.decode(to_string(response)) do
      {:ok, %{"choices" => [choice | _]} = decoded} ->
        callback.(Event.assistant_delta(get_in(choice, ["message", "content"]) || ""))
        callback.(Event.usage(decoded["usage"] || %{}))
        callback.(Event.result("OpenRouter request completed"))
        callback.(Event.done())

      _ ->
        fail(callback, "OpenRouter returned an unexpected response")
    end
  end

  defp fail(callback, message) do
    callback.(Event.error(message))
    callback.(Event.done())
  end

  defp messages(config) do
    system =
      [config[:instructions], config[:permission_mode]]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    messages = if system == "", do: [], else: [%{role: "system", content: system}]
    messages ++ [%{role: "user", content: config[:prompt] || ""}]
  end
end
