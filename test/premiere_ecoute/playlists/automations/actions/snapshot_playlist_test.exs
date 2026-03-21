defmodule PremiereEcoute.Playlists.Automations.Actions.SnapshotPlaylistTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.SnapshotPlaylist

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp track(id),
    do: %Track{provider: :spotify, track_id: id, playlist_id: "src", added_at: ~N[2024-01-01 00:00:00]}

  defp created_playlist(name),
    do: %LibraryPlaylist{provider: :spotify, playlist_id: "snap_id", title: name}

  describe "validate/1" do
    test "valid with source_playlist_id and name" do
      assert :ok = SnapshotPlaylist.validate(%{"source_playlist_id" => "src", "name" => "Snapshot %{month}"})
    end

    test "invalid without name" do
      assert {:error, _} = SnapshotPlaylist.validate(%{"source_playlist_id" => "src"})
    end

    test "invalid without source_playlist_id" do
      assert {:error, _} = SnapshotPlaylist.validate(%{"name" => "Snapshot"})
    end

    test "invalid with empty config" do
      assert {:error, _} = SnapshotPlaylist.validate(%{})
    end
  end

  describe "execute/3" do
    test "creates a new playlist, copies tracks, returns created_playlist_id and track_count" do
      tracks = [track("t1"), track("t2")]
      source = %Playlist{provider: :spotify, playlist_id: "src", tracks: tracks}

      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: "Snap March"} = pl ->
        {:ok, created_playlist(pl.title)}
      end)

      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, source} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "snap_id", ^tracks -> {:ok, %{}} end)

      config = %{"source_playlist_id" => "src", "name" => "Snap March"}

      assert {:ok, %{"created_playlist_id" => "snap_id", "track_count" => 2}} =
               SnapshotPlaylist.execute(config, %{}, scope())
    end

    test "resolves name template placeholders" do
      year = to_string(Date.utc_today().year)
      tracks = [track("t1")]
      source = %Playlist{provider: :spotify, playlist_id: "src", tracks: tracks}

      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: title} = pl ->
        assert title == "Archive #{year}"
        {:ok, created_playlist(pl.title)}
      end)

      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, source} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "snap_id", _tracks -> {:ok, %{}} end)

      config = %{"source_playlist_id" => "src", "name" => "Archive %{year}"}

      assert {:ok, %{"playlist_name" => "Archive " <> ^year}} =
               SnapshotPlaylist.execute(config, %{}, scope())
    end

    test "snapshot of empty source creates playlist with 0 tracks" do
      source = %Playlist{provider: :spotify, playlist_id: "src", tracks: []}

      expect(SpotifyApi, :create_playlist, fn _scope, pl -> {:ok, created_playlist(pl.title)} end)
      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, source} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "snap_id", [] -> {:ok, %{}} end)

      config = %{"source_playlist_id" => "src", "name" => "Empty Snapshot"}
      assert {:ok, %{"track_count" => 0}} = SnapshotPlaylist.execute(config, %{}, scope())
    end

    test "propagates error when playlist creation fails" do
      expect(SpotifyApi, :create_playlist, fn _scope, _pl -> {:error, :unauthorized} end)

      config = %{"source_playlist_id" => "src", "name" => "Snap"}
      assert {:error, :unauthorized} = SnapshotPlaylist.execute(config, %{}, scope())
    end

    test "propagates error when source fetch fails" do
      expect(SpotifyApi, :create_playlist, fn _scope, pl -> {:ok, created_playlist(pl.title)} end)
      expect(SpotifyApi, :get_playlist, fn "src" -> {:error, :not_found} end)

      config = %{"source_playlist_id" => "src", "name" => "Snap"}
      assert {:error, :not_found} = SnapshotPlaylist.execute(config, %{}, scope())
    end

    test "propagates error when adding tracks fails" do
      tracks = [track("t1")]
      source = %Playlist{provider: :spotify, playlist_id: "src", tracks: tracks}

      expect(SpotifyApi, :create_playlist, fn _scope, pl -> {:ok, created_playlist(pl.title)} end)
      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, source} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "snap_id", _tracks -> {:error, :api_error} end)

      config = %{"source_playlist_id" => "src", "name" => "Snap"}
      assert {:error, :api_error} = SnapshotPlaylist.execute(config, %{}, scope())
    end
  end
end
