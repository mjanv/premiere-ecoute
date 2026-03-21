defmodule PremiereEcoute.Playlists.Automations.Actions.MergePlaylistsTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Playlists.Automations.Actions.MergePlaylists

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp track(id, playlist_id \\ "pl"),
    do: %Track{provider: :spotify, track_id: id, playlist_id: playlist_id, added_at: ~N[2024-01-01 00:00:00]}

  describe "validate/1" do
    test "valid with two source IDs and a target" do
      assert :ok = MergePlaylists.validate(%{"source_playlist_ids" => ["a", "b"], "target_playlist_id" => "tgt"})
    end

    test "valid with $created_playlist_id reference as target" do
      assert :ok =
               MergePlaylists.validate(%{
                 "source_playlist_ids" => ["a", "b"],
                 "target_playlist_id" => "$created_playlist_id"
               })
    end

    test "invalid with only one source" do
      assert {:error, _} = MergePlaylists.validate(%{"source_playlist_ids" => ["a"], "target_playlist_id" => "tgt"})
    end

    test "invalid without target_playlist_id" do
      assert {:error, _} = MergePlaylists.validate(%{"source_playlist_ids" => ["a", "b"]})
    end

    test "invalid with empty config" do
      assert {:error, _} = MergePlaylists.validate(%{})
    end
  end

  describe "execute/3" do
    test "merges tracks from two playlists and returns merged_count" do
      pl1_tracks = [track("t1", "pl1"), track("t2", "pl1")]
      pl2_tracks = [track("t3", "pl2"), track("t4", "pl2")]
      pl1 = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: pl1_tracks}
      pl2 = %Playlist{provider: :spotify, playlist_id: "pl2", tracks: pl2_tracks}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, pl1} end)
      expect(SpotifyApi, :get_playlist, fn "pl2" -> {:ok, pl2} end)

      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "tgt", merged ->
        assert length(merged) == 4
        {:ok, %{}}
      end)

      config = %{"source_playlist_ids" => ["pl1", "pl2"], "target_playlist_id" => "tgt"}
      assert {:ok, %{merged_count: 4}} = MergePlaylists.execute(config, %{}, scope())
    end

    test "deduplicates tracks across sources" do
      shared = track("t1", "pl1")
      pl1 = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: [shared, track("t2", "pl1")]}
      pl2 = %Playlist{provider: :spotify, playlist_id: "pl2", tracks: [track("t1", "pl2"), track("t3", "pl2")]}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, pl1} end)
      expect(SpotifyApi, :get_playlist, fn "pl2" -> {:ok, pl2} end)

      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "tgt", merged ->
        assert length(merged) == 3
        assert Enum.map(merged, & &1.track_id) == ["t1", "t2", "t3"]
        {:ok, %{}}
      end)

      config = %{"source_playlist_ids" => ["pl1", "pl2"], "target_playlist_id" => "tgt"}
      assert {:ok, %{merged_count: 3}} = MergePlaylists.execute(config, %{}, scope())
    end

    test "resolves target_playlist_id from context via $created_playlist_id" do
      pl1 = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: [track("t1", "pl1")]}
      pl2 = %Playlist{provider: :spotify, playlist_id: "pl2", tracks: [track("t2", "pl2")]}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, pl1} end)
      expect(SpotifyApi, :get_playlist, fn "pl2" -> {:ok, pl2} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "ctx_pl_id", _tracks -> {:ok, %{}} end)

      config = %{"source_playlist_ids" => ["pl1", "pl2"], "target_playlist_id" => "$created_playlist_id"}
      context = %{"created_playlist_id" => "ctx_pl_id"}
      assert {:ok, %{merged_count: 2}} = MergePlaylists.execute(config, context, scope())
    end

    test "halts and propagates error on first failing source fetch" do
      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:error, :not_found} end)

      config = %{"source_playlist_ids" => ["pl1", "pl2"], "target_playlist_id" => "tgt"}
      assert {:error, :not_found} = MergePlaylists.execute(config, %{}, scope())
    end

    test "propagates API error on add_items_to_playlist" do
      pl1 = %Playlist{provider: :spotify, playlist_id: "pl1", tracks: [track("t1", "pl1")]}
      pl2 = %Playlist{provider: :spotify, playlist_id: "pl2", tracks: [track("t2", "pl2")]}

      expect(SpotifyApi, :get_playlist, fn "pl1" -> {:ok, pl1} end)
      expect(SpotifyApi, :get_playlist, fn "pl2" -> {:ok, pl2} end)
      expect(SpotifyApi, :add_items_to_playlist, fn _scope, "tgt", _tracks -> {:error, :api_error} end)

      config = %{"source_playlist_ids" => ["pl1", "pl2"], "target_playlist_id" => "tgt"}
      assert {:error, :api_error} = MergePlaylists.execute(config, %{}, scope())
    end
  end
end
