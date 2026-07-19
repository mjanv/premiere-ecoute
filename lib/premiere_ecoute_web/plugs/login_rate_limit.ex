defmodule PremiereEcouteWeb.Plugs.LoginRateLimit do
  @moduledoc """
  Rate limiting for the login endpoint.

  Bounds credential-stuffing / brute-force attempts against a known email by keying on the
  submitted email (falling back to client IP when no email is present, e.g. magic-link
  submissions). Backed by the app-wide Hammer `RateLimiter` (ETS). Over the limit returns 429
  with a `Retry-After` header.
  """

  import Plug.Conn

  alias PremiereEcoute.Apis.RateLimit.RateLimiter

  @window_ms 60_000
  @max_requests 10

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

  # Fail open: if the limiter is unavailable, never block a legitimate login.
  defp allow_or_deny(conn) do
    case RateLimiter.hit("login:" <> rate_limit_key(conn), @window_ms, @max_requests) do
      {:allow, _count} -> :allow
      {:deny, _retry_after_ms} -> :deny
    end
  rescue
    _ -> :allow
  catch
    :exit, _ -> :allow
  end

  defp rate_limit_key(%Plug.Conn{body_params: %{"user" => %{"email" => email}}}) when is_binary(email) and email != "" do
    String.downcase(email)
  end

  defp rate_limit_key(conn), do: client_ip(conn)

  defp client_ip(%Plug.Conn{remote_ip: ip}), do: ip |> :inet.ntoa() |> to_string()
end
