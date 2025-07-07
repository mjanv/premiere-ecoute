defmodule PremiereEcoute.Apis.SpotifyApi.PlayerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyApi.Player

  alias PremiereEcoute.Sessions.Discography.Album

  setup do
    scope =
      user_scope_fixture(
        user_fixture(%{
          spotify_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
        })
      )

    ApiMock.expect(
      SpotifyApi,
      path: {:post, "/api/token"},
      response: %{"access_token" => "token"},
      status: 200
    )

    {:ok, scope: scope}
  end

  describe "get_playback_state/1" do
    test "return a playing playback state", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player"},
        response: "spotify_api/player/get_playback_state/state1.json",
        status: 200
      )

      {:ok, state} = Player.get_playback_state(scope)

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
        response: %{},
        status: 204
      )

      {:ok, state} = Player.get_playback_state(scope)

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
        response: %{},
        status: 204
      )

      {:ok, :success} = Player.start_playback(scope)
    end
  end

  describe "pause_playback/1" do
    test "pause the current player", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/pause"},
        response: %{},
        status: 204
      )

      {:ok, :success} = Player.pause_playback(scope)
    end
  end

  describe "next_track/1" do
    test "skips to the next track", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/next"},
        response: %{},
        status: 204
      )

      {:ok, :success} = Player.next_track(scope)
    end
  end

  describe "previous_track/1" do
    test "skips to the previous track", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/previous"},
        response: %{},
        status: 204
      )

      {:ok, :success} = Player.previous_track(scope)
    end
  end

  describe "start_resume_playback/1" do
    setup do
      {:ok, album} = Album.create(album_fixture(%{spotify_id: "5ht7ItJgpBH7W6vJ5BqpPr"}))

      {:ok, %{album: album}}
    end

    test "can start an album play in the player", %{scope: scope, album: album} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        request: "spotify_api/player/start_resume_playback/request_album.json",
        status: 204
      )

      {:ok, context_uri} = Player.start_resume_playback(scope, album)

      assert context_uri == "spotify:album:5ht7ItJgpBH7W6vJ5BqpPr"
    end

    test "can start an track play in the player", %{scope: scope, album: album} do
      track = hd(album.tracks)

      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        request: "spotify_api/player/start_resume_playback/request_track.json",
        status: 204
      )

      {:ok, context_uri} = Player.start_resume_playback(scope, track)

      assert context_uri == "spotify:track:track001"
    end
  end

  describe "add_item_to_playback_queue/1" do
    setup do
      {:ok, album} = Album.create(album_fixture(%{spotify_id: "5ht7ItJgpBH7W6vJ5BqpPr"}))

      {:ok, %{album: album}}
    end

    test "can add a track in the player queue", %{scope: scope, album: album} do
      track = hd(album.tracks)

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        params: %{"uri" => "spotify:track:#{track.spotify_id}"},
        status: 204
      )

      {:ok, context_uri} = Player.add_item_to_playback_queue(scope, track)

      assert context_uri == "spotify:track:#{track.spotify_id}"
    end

    test "can add an album in the player queue", %{scope: scope, album: album} do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        params: %{"uri" => "spotify:track:track001"},
        status: 204
      )

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        response: %{"access_token" => "token"},
        status: 200
      )

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        params: %{"uri" => "spotify:track:track002"},
        status: 204
      )

      {:ok, context_uris} = Player.add_item_to_playback_queue(scope, album)

      assert context_uris == ["spotify:track:track001", "spotify:track:track002"]
    end

    test "fails if not all album tracks can be added in the player queue", %{
      scope: scope,
      album: album
    } do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        params: %{"uri" => "spotify:track:track001"},
        status: 204
      )

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        response: %{"access_token" => "token"},
        status: 200
      )

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/me/player/queue"},
        status: 429,
        body: %{}
      )

      {:error, reason} = Player.add_item_to_playback_queue(scope, album)

      assert reason == "Cannot queue all album tracks"
    end
  end
end
