defmodule PremiereEcoute.Apis.SpotifyApi.PlayerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

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

  describe "devices/1" do
    test "returns list of available devices", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player/devices"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/player/devices/response.json",
        status: 200
      )

      {:ok, devices} = SpotifyApi.devices(scope)

      assert devices == [
               %{
                 "id" => "1e463fc3e7d2bd24126918bde04abee6cbfb4ff2",
                 "is_active" => true,
                 "is_private_session" => false,
                 "is_restricted" => false,
                 "name" => "Kitchen speaker",
                 "type" => "computer",
                 "volume_percent" => 59,
                 "supports_volume" => false
               },
               %{
                 "id" => "a1b2c3d4e5f6789012345678901234567890abcd",
                 "is_active" => false,
                 "is_private_session" => false,
                 "is_restricted" => false,
                 "name" => "Living Room TV",
                 "type" => "tv",
                 "volume_percent" => 75,
                 "supports_volume" => true
               }
             ]
    end

    test "returns error when API call fails", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/player/devices"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: %{"error" => %{"status" => 401, "message" => "Invalid access token"}},
        status: 401
      )

      {:error, error} = SpotifyApi.devices(scope)

      assert error == []
    end
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

      {:ok, state} = SpotifyApi.get_playback_state(scope, %{})

      assert state == %{
               "device" => %{
                 "id" => "1e463fc3e7d2bd24126918bde04abee6cbfb4ff2",
                 "is_active" => true,
                 "name" => "HPE-5CG3313SL4",
                 "is_private_session" => false,
                 "is_restricted" => false,
                 "supports_volume" => true,
                 "type" => "Computer",
                 "volume_percent" => 82
               },
               "is_playing" => true,
               "item" => %{
                 "duration_ms" => 197_636,
                 "id" => "3m2VVaBylHoKBngpUflwUM",
                 "name" => "Marche ou rêve",
                 "track_number" => 1,
                 "album" => %{
                   "album_type" => "single",
                   "artists" => [
                     %{
                       "external_urls" => %{"spotify" => "https://open.spotify.com/artist/00CTomLgA78xvwEwL0woWx"},
                       "href" => "https://api.spotify.com/v1/artists/00CTomLgA78xvwEwL0woWx",
                       "id" => "00CTomLgA78xvwEwL0woWx",
                       "name" => "Suzane",
                       "type" => "artist",
                       "uri" => "spotify:artist:00CTomLgA78xvwEwL0woWx"
                     }
                   ],
                   "available_markets" => [
                     "AR",
                     "AU",
                     "AT",
                     "BE",
                     "BO",
                     "BR",
                     "BG",
                     "CA",
                     "CL",
                     "CO",
                     "CR",
                     "CY",
                     "CZ",
                     "DK",
                     "DO",
                     "DE",
                     "EC",
                     "EE",
                     "SV",
                     "FI",
                     "FR",
                     "GR",
                     "GT",
                     "HN",
                     "HK",
                     "HU",
                     "IS",
                     "IE",
                     "IT",
                     "LV",
                     "LT",
                     "LU",
                     "MY",
                     "MT",
                     "MX",
                     "NL"
                   ],
                   "external_urls" => %{"spotify" => "https://open.spotify.com/album/7kS5ShCz4QHayBwumXSdUO"},
                   "href" => "https://api.spotify.com/v1/albums/7kS5ShCz4QHayBwumXSdUO",
                   "id" => "7kS5ShCz4QHayBwumXSdUO",
                   "images" => [
                     %{
                       "height" => 640,
                       "url" => "https://i.scdn.co/image/ab67616d0000b2737231f713d20c86543c6b6717",
                       "width" => 640
                     },
                     %{
                       "height" => 300,
                       "url" => "https://i.scdn.co/image/ab67616d00001e027231f713d20c86543c6b6717",
                       "width" => 300
                     },
                     %{"height" => 64, "url" => "https://i.scdn.co/image/ab67616d000048517231f713d20c86543c6b6717", "width" => 64}
                   ],
                   "name" => "Marche ou rêve",
                   "release_date" => "2025-07-04",
                   "release_date_precision" => "day",
                   "total_tracks" => 1,
                   "type" => "album",
                   "uri" => "spotify:album:7kS5ShCz4QHayBwumXSdUO"
                 },
                 "artists" => [
                   %{
                     "external_urls" => %{"spotify" => "https://open.spotify.com/artist/00CTomLgA78xvwEwL0woWx"},
                     "href" => "https://api.spotify.com/v1/artists/00CTomLgA78xvwEwL0woWx",
                     "id" => "00CTomLgA78xvwEwL0woWx",
                     "name" => "Suzane",
                     "type" => "artist",
                     "uri" => "spotify:artist:00CTomLgA78xvwEwL0woWx"
                   }
                 ],
                 "available_markets" => [
                   "AR",
                   "AU",
                   "AT",
                   "BE",
                   "BO",
                   "BR",
                   "BG",
                   "CA",
                   "CL",
                   "CO",
                   "CR",
                   "CY",
                   "CZ",
                   "DK",
                   "DO",
                   "DE",
                   "EC",
                   "EE",
                   "SV",
                   "FI",
                   "FR",
                   "GR",
                   "GT",
                   "HN",
                   "HK",
                   "HU",
                   "IS",
                   "IE",
                   "IT",
                   "LV",
                   "LT",
                   "LU",
                   "MY",
                   "MT",
                   "MX",
                   "NL"
                 ],
                 "disc_number" => 1,
                 "explicit" => false,
                 "external_ids" => %{"isrc" => "FRERA2500020"},
                 "external_urls" => %{"spotify" => "https://open.spotify.com/track/3m2VVaBylHoKBngpUflwUM"},
                 "href" => "https://api.spotify.com/v1/tracks/3m2VVaBylHoKBngpUflwUM",
                 "is_local" => false,
                 "popularity" => 13,
                 "preview_url" => nil,
                 "type" => "track",
                 "uri" => "spotify:track:3m2VVaBylHoKBngpUflwUM"
               },
               "actions" => %{"disallows" => %{"resuming" => true}},
               "context" => %{
                 "external_urls" => %{"spotify" => "https://open.spotify.com/playlist/2gW4sqiC2OXZLe9m0yDQX7"},
                 "href" => "https://api.spotify.com/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7",
                 "type" => "playlist",
                 "uri" => "spotify:playlist:2gW4sqiC2OXZLe9m0yDQX7"
               },
               "currently_playing_type" => "track",
               "private" => %{},
               "progress_ms" => 139_418,
               "repeat_state" => "off",
               "shuffle_state" => false,
               "smart_shuffle" => false,
               "timestamp" => 1_751_794_690_009,
               "trailers" => %{}
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

      {:ok, state} = SpotifyApi.get_playback_state(scope, %{})

      assert state == %{
               "is_playing" => false,
               "device" => nil,
               "item" => nil
             }
    end
  end

  describe "start_playback/1" do
    setup do
      {:ok, album} = Album.create(album_fixture(%{album_id: "5ht7ItJgpBH7W6vJ5BqpPr"}))
      {:ok, playlist} = Playlist.create(playlist_fixture())

      {:ok, %{album: album, playlist: playlist}}
    end

    test "start the current player", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.start_playback(scope)
    end

    test "start the current player with an album context", %{scope: scope, album: album} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        request: %{
          "context_uri" => "spotify:album:5ht7ItJgpBH7W6vJ5BqpPr",
          "offset" => %{"position" => 0},
          "position_ms" => 0
        },
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.start_playback(scope, album)
    end

    test "start the current player with a playlist context", %{scope: scope, playlist: playlist} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/play"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        request: %{
          "context_uri" => "spotify:playlist:2gW4sqiC2OXZLe9m0yDQX7",
          "offset" => %{"position" => 0},
          "position_ms" => 0
        },
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.start_playback(scope, playlist)
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

  describe "set_repeat_mode/2" do
    test "sets repeat mode to track", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/repeat"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        params: %{"state" => "track"},
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.set_repeat_mode(scope, :track)
    end

    test "sets repeat mode to context", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/repeat"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        params: %{"state" => "context"},
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.set_repeat_mode(scope, :context)
    end

    test "sets repeat mode to off", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/repeat"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        params: %{"state" => "off"},
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.set_repeat_mode(scope, :off)
    end
  end

  describe "toggle_playback_shuffle/2" do
    test "enables shuffle mode", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/shuffle"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        params: %{"state" => "true"},
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.toggle_playback_shuffle(scope, true)
    end

    test "disables shuffle mode", %{scope: scope} do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/me/player/shuffle"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"},
          {"content-length", "0"}
        ],
        params: %{"state" => "false"},
        response: %{},
        status: 204
      )

      {:ok, :success} = SpotifyApi.toggle_playback_shuffle(scope, false)
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
