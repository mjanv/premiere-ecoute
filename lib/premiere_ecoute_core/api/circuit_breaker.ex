defmodule PremiereEcouteCore.Api.CircuitBreaker do
  @moduledoc """
  Circuit breaker for outbound API requests.

  Integrates as a pair of Req steps: a pre-request step that halts the request when the target API is currently rate-limited, and a post-response step that opens the circuit on HTTP 429 by storing the response body in the `:rate_limits` cache with a TTL derived from the `retry-after` header (defaulting to 60 seconds). Once the TTL expires the circuit closes automatically and requests resume.
  """

  alias PremiereEcouteCore.Cache

  @cache :rate_limits
  @status_codes [429]

  @spec run(Req.Request.t(), Keyword.t()) :: Req.Request.t()
  def run(request, opts \\ []) do
    request
    |> Req.Request.prepend_request_steps(circuit_breaker: fn request -> maybe_halt(request, opts) end)
    |> Req.Request.append_response_steps(circuit_breaker: fn {request, response} -> maybe_open({request, response}, opts) end)
  end

  defp maybe_halt(request, opts) do
    case Cache.get(@cache, opts[:api]) do
      {:ok, nil} -> request
      {:ok, reason} -> Req.Request.halt(request, RuntimeError.exception(reason))
      {:error, _} -> request
    end
  end

  defp maybe_open({request, %{status: status} = response}, opts) do
    if status in @status_codes do
      retry_after = String.to_integer(hd(response.headers["retry-after"] || ["60"]))
      Cache.put(@cache, opts[:api], response.body, expire: retry_after * 1_000)
    end

    {request, response}
  end

  def up(api, ttl \\ 10), do: Cache.put(@cache, api, "simulated incident", expire: ttl * 1_000)
  def down(api), do: Cache.del(@cache, api)
end
