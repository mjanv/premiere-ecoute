defmodule PremiereEcouteWeb.Plugs.PodcastRateLimitTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias PremiereEcouteWeb.Plugs.PodcastRateLimit

  setup do
    start_supervised(PremiereEcoute.Apis.RateLimit.RateLimiter)
    :ok
  end

  defp request(ip), do: %{conn(:get, "/podcasts/x/y/feed.xml") | remote_ip: ip}

  test "allows requests under the limit, then 429s with Retry-After" do
    ip = {10, 0, 0, :rand.uniform(254)}

    for _ <- 1..120 do
      refute PodcastRateLimit.call(request(ip), []).halted
    end

    denied = PodcastRateLimit.call(request(ip), [])

    assert denied.status == 429
    assert denied.halted
    assert get_resp_header(denied, "retry-after") == ["60"]
  end
end
