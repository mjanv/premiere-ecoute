defmodule PremiereEcouteWeb.Plugs.PodcastRateLimit do
  @moduledoc """
  Per-IP rate limiting for the public podcast endpoints (feed, audio, cover).

  These are unauthenticated and (for audio) proxy real bytes, so they need a throttle to bound
  egress/CPU abuse. Backed by the app-wide Hammer `RateLimiter` (ETS). Over the limit returns
  429 with a `Retry-After` header.
  """

  import Plug.Conn

  alias PremiereEcoute.Apis.RateLimit.RateLimiter

  @window_ms 60_000
  @max_requests 120

  def init(opts), do: opts

  def call(conn, _opts) do
    case allow_or_deny(conn) do
      :allow ->
        conn

      :deny ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(div(@window_ms, 1000)))
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end

  # Fail open: if the limiter is unavailable, never 500 the public feed/audio.
  defp allow_or_deny(conn) do
    case RateLimiter.hit("podcast_public:" <> client_ip(conn), @window_ms, @max_requests) do
      {:allow, _count} -> :allow
      {:deny, _retry_after_ms} -> :deny
    end
  rescue
    _ -> :allow
  catch
    :exit, _ -> :allow
  end

  defp client_ip(%Plug.Conn{remote_ip: ip}), do: ip |> :inet.ntoa() |> to_string()
end
