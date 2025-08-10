defmodule PremiereEcoute.Apis.SpotifyApi.PlayerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Discography.Album

  setup do
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
    test "return a playing playback state", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}, {"content-type", "application/json"}],
        response: "spotify_api/player/get_playback_state/state1.json",
        status: 200
      )

      {:ok, state} = SpotifyApi.get_playback_state(scope)

      assert state == %{
               "is_playing" => true,
               "device" => %{
                 "id" => "1e463fc3e7d2bd24126918bde04abee6cbfb4ff2",
                 "is_active" => true,
                 "name" => "HPE-5CG3313SL4"
               },
               "item" => %{
                 "id" => "3m2VVaBylHoKBngpUflwUM",
                 "name" => "Marche ou rêve",
                 "track_number" => 1,
                 "progress_ms" => 139_418,
                 "duration_ms" => 197_636
               }
             }
    end

    test "return a non-playing playback state", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}, {"content-type", "application/json"}],
        response: %{},
        status: 204
      )

      {:ok, state} = SpotifyApi.get_playback_state(scope)

      assert state == %{
               "is_playing" => false,
               "device" => nil,
               "item" => nil
             }
    end
  end

  describe "start_playback/1" do
    test "start the current player", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "2"}
        ],
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.start_playback(scope)
    end
  end

  describe "pause_playback/1" do
    test "pause the current player", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/pause"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.pause_playback(scope)
    end
  end

  describe "next_track/1" do
    test "skips to the next track", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/next"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.next_track(scope)
    end
  end

  describe "previous_track/1" do
    test "skips to the previous track", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/previous"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.previous_track(scope)
    end
  end

  describe "start_resume_playback/1" do
    setup do
      {:ok, album} = Album.create(album_fixture(%{album_id: "5ht7ItJgpBH7W6vJ5BqpPr"}))

      {:ok, %{album: album}}
    end

    test "can start an album play in the player", %{scope: scope, album: album} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}, {"content-type", "application/json"}],
        request: "spotify_api/player/start_resume_playback/request_album.json",
        status: 204
      )

      {:ok, context_uri} = SpotifyApi.start_resume_playback(scope, album)

      assert context_uri == "spotify:album:5ht7ItJgpBH7W6vJ5BqpPr"
    end

    test "can start an track play in the player", %{scope: scope, album: album} do
      track = hd(album.tracks)

      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}],
        request: "spotify_api/player/start_resume_playback/request_track.json",
        status: 204
      )

      {:ok, context_uri} = SpotifyApi.start_resume_playback(scope, track)

      assert context_uri == "spotify:track:track001"
    end
  end

  describe "add_item_to_playback_queue/1" do
    setup do
      {:ok, album} = Album.create(album_fixture(%{album_id: "5ht7ItJgpBH7W6vJ5BqpPr"}))

      {:ok, %{album: album}}
    end

    test "can add a track in the player queue", %{scope: scope, album: album} do
      track = hd(album.tracks)

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        params: %{"uri" => "spotify:track:#{track.track_id}"},
        status: 204
      )

      {:ok, context_uri} = SpotifyApi.add_item_to_playback_queue(scope, track)

      assert context_uri == "spotify:track:#{track.track_id}"
    end

    test "can add an album in the player queue", %{scope: scope, album: album} do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}],
        params: %{"uri" => "spotify:track:track001"},
        status: 204
      )

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}],
        params: %{"uri" => "spotify:track:track002"},
        status: 204
      )

      {:ok, context_uris} = SpotifyApi.add_item_to_playback_queue(scope, album)

      assert context_uris == ["spotify:track:track001", "spotify:track:track002"]
    end

    test "fails if not all album tracks can be added in the player queue", %{
      scope: scope,
      album: album
    } do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}],
        params: %{"uri" => "spotify:track:track001"},
        status: 204
      )

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        headers: [{"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"}],
        status: 429,
        body: %{}
      )

      {:error, reason} = SpotifyApi.add_item_to_playback_queue(scope, album)

      assert reason == "Cannot queue all album tracks"
    end
  end
end
