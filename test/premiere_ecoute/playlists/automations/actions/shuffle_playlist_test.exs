defmodule PremiereEcoute.Playlists.Automations.Actions.ShufflePlaylistTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.ShufflePlaylist

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp track(id),
    do: %Track{provider: :spotify, track_id: id, playlist_id: "pl1", added_at: ~N[2024-01-01 00:00:00]}

  describe "validate/1" do
    test "valid with playlist_id" do
      assert :ok = ShufflePlaylist.validate(%{"playlist_id" => "abc123"})
    end

    test "invalid without playlist_id" do
      assert {:error, _} = ShufflePlaylist.validate(%{})
    end

    test "invalid with empty playlist_id" do
      assert {:error, _} = ShufflePlaylist.validate(%{"playlist_id" => ""})
    end
  end

  describe "execute/3" do
    test "returns track_count 0 when playlist is empty" do
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: []}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)

      assert {:ok, %{track_count: 0}} = ShufflePlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "shuffles tracks and returns track_count" do
      tracks = [track("t1"), track("t2"), track("t3")]
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)

      expect(SpotifyApi, :replace_items_to_playlist, fn _scope, "pl1", shuffled ->
        assert length(shuffled) == 3
        assert Enum.sort_by(shuffled, & &1.track_id) == Enum.sort_by(tracks, & &1.track_id)
        {:ok, %{}}
      end)

      assert {:ok, %{track_count: 3}} = ShufflePlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "propagates API error on get_playlist" do
      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:error, :not_found} end)

      assert {:error, :not_found} = ShufflePlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "handles playlists with more than 100 tracks" do
      tracks = Enum.map(1..150, &track("t#{&1}"))
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)

      expect(SpotifyApi, :replace_items_to_playlist, fn _scope, "pl1", shuffled ->
        assert length(shuffled) == 150
        assert Enum.sort_by(shuffled, & &1.track_id) == Enum.sort_by(tracks, & &1.track_id)
        {:ok, %{}}
      end)

      assert {:ok, %{track_count: 150}} = ShufflePlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "propagates API error on replace_items_to_playlist" do
      tracks = [track("t1"), track("t2")]
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)
      expect(SpotifyApi, :replace_items_to_playlist, fn _scope, "pl1", _shuffled -> {:error, :api_error} end)

      assert {:error, :api_error} = ShufflePlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end
  end
end
