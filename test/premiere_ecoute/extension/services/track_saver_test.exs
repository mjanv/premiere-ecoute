defmodule PremiereEcoute.Extension.Services.TrackSaverTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Extension.Services.TrackSaver
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist

  describe "save_track/2" do
    setup do
      user = user_fixture(%{
        twitch: %{user_id: "user123"},
        spotify: %{user_id: "spotify_user_123"}
      })

      {:ok, user: user}
    end

    test "saves track to matching playlist successfully", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "spotify_track_123"
      
      # Mock playlist data with a matching playlist
      matching_playlist = %LibraryPlaylist{
        playlist_id: "playlist_123",
        title: "My Flonflon Hits",
        description: "My favorite tracks from streams",
        provider: :spotify,
        track_count: 42,
        public: true
      }

      other_playlist = %LibraryPlaylist{
        playlist_id: "playlist_456", 
        title: "Regular Playlist",
        description: "Just another playlist",
        provider: :spotify,
        track_count: 10,
        public: true
      }

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:ok, [other_playlist, matching_playlist]}
      end)

      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, "playlist_123", [%{track_id: ^spotify_track_id}] ->
        {:ok, %{"snapshot_id" => "snapshot_123"}}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:ok, "My Flonflon Hits"}
    end

    test "finds case-insensitive matching playlist", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "spotify_track_456"
      
      # Mock playlist with different case
      flonflon_playlist = %LibraryPlaylist{
        playlist_id: "playlist_789",
        title: "FLONFLON Favorites", 
        description: "Uppercase variant",
        provider: :spotify,
        track_count: 15,
        public: true
      }

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:ok, [flonflon_playlist]}
      end)

      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, "playlist_789", [%{track_id: ^spotify_track_id}] ->
        {:ok, %{"snapshot_id" => "snapshot_789"}}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:ok, "FLONFLON Favorites"}
    end

    test "returns error when user not found" do
      user_id = "nonexistent_user"
      spotify_track_id = "some_track"

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:error, :no_user}
    end

    test "returns error when user has no Spotify connection" do
      user = user_fixture(%{
        twitch: %{user_id: "user456"}
      })
      
      user_id = user.twitch.user_id
      spotify_track_id = "some_track"

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:error, :no_spotify}
    end

    test "returns error when no matching playlist found", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "some_track"
      
      # Mock playlists without any containing "flonflon"
      other_playlists = [
        %LibraryPlaylist{
          playlist_id: "playlist_111",
          title: "Rock Hits",
          description: "Rock music collection",
          provider: :spotify,
          track_count: 25,
          public: true
        },
        %LibraryPlaylist{
          playlist_id: "playlist_222", 
          title: "Jazz Collection",
          description: "Smooth jazz tracks",
          provider: :spotify,
          track_count: 18,
          public: true
        }
      ]

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:ok, other_playlists}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:error, :no_matching_playlist}
    end

    test "returns error when get_library_playlists fails", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "some_track"

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:error, :api_error}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:error, :api_error}
    end

    test "returns error when add_items_to_playlist fails", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "failing_track"
      
      flonflon_playlist = %LibraryPlaylist{
        playlist_id: "playlist_fail",
        title: "Flonflon Fails",
        description: "This will fail",
        provider: :spotify,
        track_count: 5,
        public: true
      }

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:ok, [flonflon_playlist]}
      end)

      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, "playlist_fail", [%{track_id: ^spotify_track_id}] ->
        {:error, :playlist_add_failed}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:error, :playlist_add_failed}
    end

    test "finds first matching playlist when multiple exist", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "multi_track"
      
      # Multiple playlists with "flonflon" in the name
      first_flonflon = %LibraryPlaylist{
        playlist_id: "first_flonflon",
        title: "First Flonflon",
        description: "First one",
        provider: :spotify,
        track_count: 10,
        public: true
      }

      second_flonflon = %LibraryPlaylist{
        playlist_id: "second_flonflon",
        title: "Second Flonflon Mix", 
        description: "Second one",
        provider: :spotify,
        track_count: 20,
        public: true
      }

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:ok, [first_flonflon, second_flonflon]}
      end)

      # Should use the first one found
      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, "first_flonflon", [%{track_id: ^spotify_track_id}] ->
        {:ok, %{"snapshot_id" => "first_snapshot"}}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:ok, "First Flonflon"}
    end

    test "handles partial matches in playlist titles", %{user: user} do
      user_id = user.twitch.user_id
      spotify_track_id = "partial_track"
      
      # Playlist with "flonflon" as substring
      substring_playlist = %LibraryPlaylist{
        playlist_id: "substring_playlist",
        title: "My Superflonflon Collection",
        description: "Contains flonflon as substring",
        provider: :spotify,
        track_count: 8,
        public: true
      }

      expect(SpotifyApi, :get_library_playlists, fn %Scope{user: ^user} ->
        {:ok, [substring_playlist]}
      end)

      expect(SpotifyApi, :add_items_to_playlist, fn %Scope{user: ^user}, "substring_playlist", [%{track_id: ^spotify_track_id}] ->
        {:ok, %{"snapshot_id" => "substring_snapshot"}}
      end)

      result = TrackSaver.save_track(user_id, spotify_track_id, "flonflon")

      assert result == {:ok, "My Superflonflon Collection"}
    end
  end
end