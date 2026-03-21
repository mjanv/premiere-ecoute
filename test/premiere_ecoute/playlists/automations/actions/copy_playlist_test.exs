defmodule PremiereEcoute.Playlists.Automations.Actions.CopyPlaylistTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.CopyPlaylist

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp track(id),
    do: %Track{provider: :spotify, track_id: id, playlist_id: "src", added_at: ~N[2024-01-01 00:00:00]}

  describe "validate/1" do
    test "valid with both playlist IDs" do
      assert :ok = CopyPlaylist.validate(%{"source" => "src", "target" => "tgt"})
    end

    test "valid with $created_playlist_id reference" do
      assert :ok = CopyPlaylist.validate(%{"source" => "src", "target" => "$created_playlist_id"})
    end

    test "invalid without source_playlist_id" do
      assert {:error, _} = CopyPlaylist.validate(%{"target" => "tgt"})
    end

    test "invalid without target_playlist_id" do
      assert {:error, _} = CopyPlaylist.validate(%{"source" => "src"})
    end

    test "invalid with empty config" do
      assert {:error, _} = CopyPlaylist.validate(%{})
    end
  end

  describe "execute/3" do
    test "copies all tracks and returns copied_count" do
      tracks = [track("t1"), track("t2"), track("t3")]
      playlist = %Playlist{provider: :spotify, playlist_id: "src", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, playlist} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "tgt", ^tracks -> {:ok, %{}} end)

      config = %{"source" => "src", "target" => "tgt"}
      assert {:ok, %{copied_count: 3}} = CopyPlaylist.execute(config, %{}, scope())
    end

    test "copies 0 tracks when source is empty" do
      playlist = %Playlist{provider: :spotify, playlist_id: "src", tracks: []}

      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, playlist} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "tgt", [] -> {:ok, %{}} end)

      config = %{"source" => "src", "target" => "tgt"}
      assert {:ok, %{copied_count: 0}} = CopyPlaylist.execute(config, %{}, scope())
    end

    test "resolves target_playlist_id from context via $created_playlist_id" do
      tracks = [track("t1")]
      playlist = %Playlist{provider: :spotify, playlist_id: "src", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, playlist} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "ctx_pl_id", ^tracks -> {:ok, %{}} end)

      config = %{"source" => "src", "target" => "$created_playlist_id"}
      context = %{"created_playlist_id" => "ctx_pl_id"}
      assert {:ok, %{copied_count: 1}} = CopyPlaylist.execute(config, context, scope())
    end

    test "propagates API error on get_playlist" do
      expect(SpotifyApi, :get_playlist, fn "src" -> {:error, :not_found} end)

      config = %{"source" => "src", "target" => "tgt"}
      assert {:error, :not_found} = CopyPlaylist.execute(config, %{}, scope())
    end

    test "propagates API error on add_items_to_playlist" do
      tracks = [track("t1")]
      playlist = %Playlist{provider: :spotify, playlist_id: "src", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "src" -> {:ok, playlist} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "tgt", _tracks -> {:error, :api_error} end)

      config = %{"source" => "src", "target" => "tgt"}
      assert {:error, :api_error} = CopyPlaylist.execute(config, %{}, scope())
    end
  end
end
