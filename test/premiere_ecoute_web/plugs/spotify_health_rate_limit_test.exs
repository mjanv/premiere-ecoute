defmodule PremiereEcouteWeb.Plugs.SpotifyHealthRateLimitTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias PremiereEcouteWeb.Plugs.SpotifyHealthRateLimit

  setup do
    start_supervised(PremiereEcoute.Apis.RateLimit.RateLimiter)
    :ok
  end

  defp request(ip), do: %{conn(:get, "/health/spotify") | remote_ip: ip}

  test "allows requests under the limit, then 429s with Retry-After" do
    ip = {10, 0, 1, :rand.uniform(254)}

    for _ <- 1..6 do
      refute SpotifyHealthRateLimit.call(request(ip), []).halted
    end

    denied = SpotifyHealthRateLimit.call(request(ip), [])

    assert denied.status == 429
    assert denied.halted
    assert get_resp_header(denied, "retry-after") == ["60"]
  end

  test "tracks limits independently per IP" do
    ip_a = {10, 0, 2, :rand.uniform(254)}
    ip_b = {10, 0, 3, :rand.uniform(254)}

    for _ <- 1..6, do: refute(SpotifyHealthRateLimit.call(request(ip_a), []).halted)

    refute SpotifyHealthRateLimit.call(request(ip_b), []).halted
  end
end
