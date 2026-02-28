defmodule PremiereEcoute.Festivals.Services.TrackSearchTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApiMock
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Festivals.Festival
  alias PremiereEcoute.Festivals.Festival.Concert
  alias PremiereEcoute.Festivals.Services.TrackSearch

  describe "create_festival_playlist/3" do
    test "can create a festival playlist on Spotify with tracks" do
      user = user_fixture(%{spotify: %{user_id: "test_user", access_token: "access_token"}})
      scope = user_scope_fixture(user)

      festival = %Festival{name: "Test Festival"}

      tracks = [
        %Track{provider: :spotify, track_id: "track1", name: "Song 1"},
        %Track{provider: :spotify, track_id: "track2", name: "Song 2"}
      ]

      created_playlist = %LibraryPlaylist{
        provider: :spotify,
        playlist_id: "test_playlist_id",
        title: "Test Festival",
        public: false,
        track_count: 0
      }

      SpotifyApiMock
      |> expect(:create_playlist, fn _scope, playlist ->
        assert playlist.title == "Test Festival"
        {:ok, created_playlist}
      end)
      |> expect(:add_items_to_playlist, fn _scope, "test_playlist_id", tracks_to_add ->
        assert length(tracks_to_add) == 2
        {:ok, %{"snapshot_id" => "test_snapshot"}}
      end)

      {:ok, result} = TrackSearch.create_festival_playlist(scope, festival, tracks)

      assert %{"snapshot_id" => "test_snapshot"} = result
    end
  end

  describe "find_tracks/2" do
    test "can find tracks for all concerts in a festival" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      festival = %Festival{
        name: "Test Festival",
        concerts: [
          %Concert{artist: "Mika", date: ~D[2024-04-23]},
          %Concert{artist: "Coldplay", date: ~D[2024-04-24]}
        ]
      }

      SpotifyApiMock
      |> expect(:search_artist, 2, fn artist ->
        {:ok, %{id: "artist_#{artist}_id"}}
      end)
      |> expect(:get_artist_top_track, 2, fn artist_id ->
        track_name =
          case artist_id do
            "artist_Mika_id" -> "Grace Kelly"
            "artist_Coldplay_id" -> "Yellow"
            _ -> "Unknown Track"
          end

        {:ok, %PlaylistTrack{provider: :spotify, track_id: "track_#{artist_id}", name: track_name}}
      end)

      updated_festival = TrackSearch.find_tracks(scope, festival)

      assert %Festival{concerts: concerts} = updated_festival
      assert length(concerts) == 2

      assert Enum.all?(concerts, fn concert -> concert.track != nil end)

      for concert <- concerts do
        assert %Concert.Track{provider: "spotify", track_id: _track_id, name: _name} = concert.track
      end
    end
  end

  describe "find_track/1" do
    test "can find a top track for a given concert artist" do
      concert = %Concert{artist: "Radiohead", date: ~D[2024-04-23]}

      SpotifyApiMock
      |> expect(:search_artist, fn "Radiohead" ->
        {:ok, %{id: "radiohead_artist_id"}}
      end)
      |> expect(:get_artist_top_track, fn "radiohead_artist_id" ->
        {:ok, %PlaylistTrack{provider: :spotify, track_id: "paranoid_android_id", name: "Paranoid Android"}}
      end)

      track = TrackSearch.find_track(concert)

      assert %Concert.Track{
               provider: "spotify",
               track_id: "paranoid_android_id",
               name: "Paranoid Android"
             } = track
    end

    test "returns nil when artist is not found" do
      concert = %Concert{artist: "Unknown Artist", date: ~D[2024-04-23]}

      SpotifyApiMock
      |> expect(:search_artist, fn "Unknown Artist" ->
        {:error, "Artist not found"}
      end)

      track = TrackSearch.find_track(concert)

      assert track == nil
    end

    test "returns nil when top tracks request fails" do
      concert = %Concert{artist: "Test Artist", date: ~D[2024-04-23]}

      SpotifyApiMock
      |> expect(:search_artist, fn "Test Artist" ->
        {:ok, %{id: "test_artist_id"}}
      end)
      |> expect(:get_artist_top_track, fn "test_artist_id" ->
        {:error, "No tracks found"}
      end)

      track = TrackSearch.find_track(concert)

      assert track == nil
    end
  end
end
