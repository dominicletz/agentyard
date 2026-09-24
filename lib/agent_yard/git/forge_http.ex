defmodule AgentYard.Git.ForgeHTTP do
  @moduledoc false

  def request(method, url, token, body \\ nil) do
    headers = [
      {~c"authorization", to_charlist("Bearer #{token}")},
      {~c"accept", ~c"application/vnd.github+json"},
      {~c"content-type", ~c"application/json"}
    ]

    request =
      case body do
        nil -> {to_charlist(url), headers}
        body -> {to_charlist(url), headers, ~c"application/json", Jason.encode!(body)}
      end

    case :httpc.request(method, request, [], []) do
      {:ok, {{_, status, _}, _headers, response}} when status in 200..299 ->
        Jason.decode(to_string(response))

      {:ok, {{_, status, _}, _headers, response}} ->
        {:error, {:http_error, status, to_string(response)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def slug(remote_url) do
    remote_url
    |> String.trim_trailing(".git")
    |> String.split("/")
    |> Enum.take(-2)
    |> Enum.join("/")
  end
end
