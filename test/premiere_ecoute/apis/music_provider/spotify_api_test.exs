defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApiTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    start_supervised({Cache, name: :rate_limits})

    scope =
      user_scope_fixture(
        user_fixture(%{
          spotify: %{access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
        })
      )

    Cache.put(:tokens, :spotify, "token")

    {:ok, scope: scope}
  end

  describe "get_playback_state/1" do
    test "activate the circuit breaker on 429 HTTP status code responses", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}, {"content-type", "application/json"}],
        body: "Too many requests",
        resp_headers: %{
          "access-control-allow-credentials" => ["true"],
          "access-control-allow-headers" => [
            "Accept, App-Platform, Authorization, Content-Type, Origin, Retry-After, Spotify-App-Version, X-Cloud-Trace-Context, client-token, content-access-token"
          ],
          "access-control-allow-methods" => ["GET, POST, OPTIONS, PUT, DELETE, PATCH"],
          "access-control-allow-origin" => ["*"],
          "access-control-max-age" => ["604800"],
          "alt-svc" => ["h3=\":443\"; ma=2592000,h3-29=\":443\"; ma=2592000"],
          "cache-control" => ["private, max-age=0"],
          "date" => ["Fri, 20 Feb 2026 07:44:59 GMT"],
          "retry-after" => ["36537"],
          "server" => ["envoy"],
          "strict-transport-security" => ["max-age=31536000"],
          "via" => ["HTTP/2 edgeproxy, 1.1 google"],
          "x-content-type-options" => ["nosniff"]
        },
        status: 429
      )

      {:error, "Spotify rate limit exceeded"} = SpotifyApi.get_playback_state(scope, %{})
      {:ok, message} = Cache.get(:rate_limits, :spotify)
      {:ok, ttl} = Cache.ttl(:rate_limits, :spotify)

      assert message == "Too many requests"
      assert_in_delta ttl, 36_537_000, 100

      assert {:error, "Network error during playback state"} = SpotifyApi.get_playback_state(scope, %{})
      assert {:error, "Network error during playback state"} = SpotifyApi.get_playback_state(scope, %{})
    end

    test "activate the circuit breaker on 429 HTTP status code responses without defined retry-after", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}, {"content-type", "application/json"}],
        body: "Too many requests",
        resp_headers: %{},
        status: 429
      )

      {:error, "Spotify rate limit exceeded"} = SpotifyApi.get_playback_state(scope, %{})
      {:ok, message} = Cache.get(:rate_limits, :spotify)
      {:ok, ttl} = Cache.ttl(:rate_limits, :spotify)

      assert message == "Too many requests"
      assert_in_delta ttl, 60_000, 100

      assert {:error, "Network error during playback state"} = SpotifyApi.get_playback_state(scope, %{})
      assert {:error, "Network error during playback state"} = SpotifyApi.get_playback_state(scope, %{})
    end
  end
end
