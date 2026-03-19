defmodule PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicatesTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicates

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp track(id),
    do: %Track{provider: :spotify, track_id: id, playlist_id: "pl1", added_at: ~N[2024-01-01 00:00:00]}

  describe "validate_config/1" do
    test "valid with playlist_id" do
      assert :ok = RemoveDuplicates.validate_config(%{"playlist_id" => "abc123"})
    end

    test "invalid without playlist_id" do
      assert {:error, _} = RemoveDuplicates.validate_config(%{})
    end
  end

  describe "execute/3" do
    test "returns removed_count 0 when no duplicates" do
      tracks = [track("t1"), track("t2"), track("t3")]
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)

      assert {:ok, %{removed_count: 0}} = RemoveDuplicates.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "removes duplicate tracks and returns removed_count" do
      t1 = track("t1")
      t2 = track("t2")
      t1_dup = track("t1")
      tracks = [t1, t2, t1_dup]
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)
      # AIDEV-NOTE: only the duplicate (second occurrence of t1) is removed
      expect(SpotifyApi, :remove_playlist_items, fn _scope, "pl1", dups ->
        assert length(dups) == 1
        {:ok, %{}}
      end)

      assert {:ok, %{removed_count: 1}} = RemoveDuplicates.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "returns removed_count 0 when playlist is empty" do
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: []}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)

      assert {:ok, %{removed_count: 0}} = RemoveDuplicates.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "propagates API error on get_playlist" do
      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:error, :not_found} end)

      assert {:error, :not_found} = RemoveDuplicates.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end

    test "propagates API error on remove_playlist_items" do
      t1 = track("t1")
      t1_dup = track("t1")
      playlist = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: [t1, t1_dup]}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, playlist} end)
      expect(SpotifyApi, :remove_playlist_items, fn _scope, "pl1", _dups -> {:error, :api_error} end)

      assert {:error, :api_error} = RemoveDuplicates.execute(%{"playlist_id" => "pl1"}, %{}, scope())
    end
  end
end
