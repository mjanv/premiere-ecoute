defmodule PremiereEcouteCore.Api.CircuitBreaker do
  @moduledoc """
  Circuit breaker for outbound API requests.

  Integrates as a pair of Req steps: a pre-request step that halts the request when the target API is currently rate-limited, and a post-response step that opens the circuit on HTTP 429 by storing the response body in the `:rate_limits` cache with a TTL derived from the `retry-after` header (defaulting to 60 seconds). Once the TTL expires the circuit closes automatically and requests resume.
  """

  alias PremiereEcouteCore.Cache

  @cache :rate_limits
  @status_codes [429]
  @transient_error_codes [503]
  @transient_ttl_seconds 30

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
    cond do
      status in @status_codes ->
        retry_after = retry_after_seconds(hd(response.headers["retry-after"] || ["60"]))
        Cache.put(@cache, opts[:api], response.body, expire: retry_after * 1_000)

      status in @transient_error_codes ->
        Cache.put(@cache, opts[:api], "service unavailable (#{status})", expire: @transient_ttl_seconds * 1_000)

      true ->
        :ok
    end

    {request, response}
  end

  @doc """
  Parses a Retry-After header value into a delay in seconds.

  RFC 7231 §7.1.3 allows Retry-After to be either delay-seconds (e.g. "120") or an HTTP-date
  (e.g. "Fri, 31 Dec 1999 23:59:59 GMT"). Falls back to 60 seconds if the value is neither.
  """
  @spec retry_after_seconds(String.t()) :: integer()
  def retry_after_seconds(value) do
    case Integer.parse(value) do
      {seconds, ""} ->
        seconds

      _ ->
        case Timex.parse(value, "{RFC1123}") do
          {:ok, retry_at} -> max(DateTime.diff(retry_at, DateTime.utc_now(), :second), 0)
          _ -> 60
        end
    end
  end

  def up(api, ttl \\ 10), do: Cache.put(@cache, api, "simulated incident", expire: ttl * 1_000)
  def down(api), do: Cache.del(@cache, api)
end
