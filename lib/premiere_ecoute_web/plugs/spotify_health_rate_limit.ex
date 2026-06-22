defmodule PremiereEcouteWeb.Plugs.SpotifyHealthRateLimit do
  @moduledoc """
  Per-IP rate limiting for `/health/spotify`.

  Each request triggers several real calls to the Spotify Web API, so this endpoint needs
  a tighter throttle than a plain health check to avoid being used to hammer Spotify.
  Backed by the app-wide Hammer `RateLimiter` (ETS). Over the limit returns 429 with a
  `Retry-After` header.
  """

  import Plug.Conn

  alias PremiereEcoute.Apis.RateLimit.RateLimiter

  @window_ms 60_000
  @max_requests 6

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

  # Fail open: if the limiter is unavailable, never 500 the health endpoint.
  defp allow_or_deny(conn) do
    case RateLimiter.hit("spotify_health:" <> client_ip(conn), @window_ms, @max_requests) do
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
