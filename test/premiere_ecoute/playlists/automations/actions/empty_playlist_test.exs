defmodule PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylistTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp track(id),
    do: %Track{provider: :spotify, track_id: id, playlist_id: "pl1", added_at: ~N[2024-01-01 00:00:00]}

  describe "validate_config/1" do
    test "valid with playlist_id" do
      assert :ok = EmptyPlaylist.validate_config(%{"playlist_id" => "abc123"})
    end

    test "invalid without playlist_id" do
      assert {:error, _} = EmptyPlaylist.validate_config(%{})
    end
  end

  describe "execute/3" do
    test "removes all tracks and returns removed_count" do
      tracks = [track("t1"), track("t2")]
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)
      expect(SpotifyApi, :remove_playlist_items, fn _scope, "pl1", ^tracks -> {:ok, %{}} end)

      assert {:ok, %{removed_count: 2}} = EmptyPlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "returns removed_count 0 when playlist is already empty" do
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: []}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)

      assert {:ok, %{removed_count: 0}} = EmptyPlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "propagates API error" do
      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:error, :not_found} end)

      assert {:error, :not_found} = EmptyPlaylist.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end
  end
end
