defmodule IExClaw.LLMClient do
  @moduledoc """
  Thin LLM adapter for OpenAI-compatible APIs (OpenRouter, Z.AI, etc.).

  `call(model, messages, tools, opts)` → `{:tool_calls, ...} | {:message, ...} | {:error, ...}`

  Owns the HTTP call, response parsing, and tool-call detection.
  Does NOT own the agent loop — that's the agent's job.

  Extracted from Code + Goal's duplicated `call_llm/1` on 2026-04-05.
  """

  @default_base_url "https://openrouter.ai/api/v1"
  @default_temperature 0.3
  @default_max_tokens 8192
  @default_timeout 120_000

  @type message :: map()
  @type tool_schema :: [map()]
  @type call_result ::
          {:tool_calls, [map()], assistant_msg :: map()}
          | {:message, String.t()}
          | {:error, term()}

  @doc """
  Call an LLM with messages and tools.

  ## Options
    * `:api_key` — required, Bearer token
    * `:base_url` — API base URL (default: OpenRouter)
    * `:temperature` — sampling temperature (default: 0.3)
    * `:max_tokens` — max response tokens (default: 8192)
    * `:timeout` — HTTP receive timeout in ms (default: 120_000)
  """
  @spec call(String.t(), [message()], tool_schema(), keyword()) :: call_result()
  def call(model, messages, tools, opts \\ []) do
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.get(opts, :base_url, @default_base_url)
    temperature = Keyword.get(opts, :temperature, @default_temperature)
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body =
      maybe_add_tools(
        %{"model" => model, "messages" => messages, "temperature" => temperature, "max_tokens" => max_tokens},
        tools
      )

    case Req.post("#{base_url}/chat/completions",
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ],
           receive_timeout: timeout
         ) do
      {:ok, %{status: 200, body: resp}} ->
        parse_response(resp)

      {:ok, %{status: status, body: resp_body}} ->
        {:error, "HTTP #{status}: #{inspect(resp_body)}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # Don't send tools key if empty — some providers choke on empty arrays
  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, "tools", tools)

  @spec parse_response(map()) :: call_result()
  defp parse_response(resp) do
    choice = hd(resp["choices"])
    msg = choice["message"]

    cond do
      msg["tool_calls"] && msg["tool_calls"] != [] ->
        {:tool_calls, msg["tool_calls"], msg}

      msg["content"] ->
        {:message, msg["content"]}

      true ->
        {:error, "Empty response from LLM"}
    end
  end
end
