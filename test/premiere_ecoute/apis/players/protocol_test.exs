defmodule PremiereEcoute.Apis.Players.ProtocolTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.Protocol

  @uri "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"

  defp payload(extra) do
    %{
      "seq" => 1,
      "snapshot" =>
        Map.merge(
          %{
            "running" => true,
            "playback" => "playing",
            "uri" => @uri,
            "title" => "Song",
            "artist" => "Artist",
            "album" => "Album",
            "position_ms" => 12_345,
            "length_ms" => 215_000,
            "volume" => 0.5
          },
          extra
        )
    }
  end

  defp snapshot(extra \\ %{}) do
    {:ok, 1, snapshot} = Protocol.snapshot(payload(extra))
    snapshot
  end

  describe "snapshot/1" do
    test "reads the album position, the genres and the modes" do
      snapshot =
        snapshot(%{
          "album_artist" => "Album Artist",
          "track_number" => 3,
          "album_track_count" => 12,
          "genres" => ["Rock", "Pop"],
          "shuffle" => true,
          "repeat" => "list"
        })

      assert %{
               album_artist: "Album Artist",
               track_number: 3,
               album_track_count: 12,
               genres: ["Rock", "Pop"],
               shuffle: true,
               repeat: :list
             } = snapshot
    end

    test "accepts a player that does not send them yet" do
      assert %{album_artist: "", track_number: nil, album_track_count: nil, genres: [], shuffle: nil, repeat: nil} = snapshot()
    end

    test "accepts null values for what the player does not know" do
      snapshot = snapshot(%{"track_number" => nil, "album_track_count" => nil, "shuffle" => nil, "repeat" => nil})

      assert %{track_number: nil, album_track_count: nil, shuffle: nil, repeat: nil} = snapshot
    end

    test "drops an extra of the wrong type instead of refusing the snapshot" do
      snapshot =
        snapshot(%{
          "track_number" => -1,
          "album_track_count" => "12",
          "genres" => "Rock",
          "shuffle" => "yes",
          "repeat" => "sometimes"
        })

      assert %{track_number: nil, album_track_count: nil, genres: [], shuffle: nil, repeat: nil} = snapshot
    end

    test "keeps at most 10 genres, cut to 512 characters, and skips what is not text" do
      long = String.duplicate("é", 600)
      snapshot = snapshot(%{"genres" => [long, 1 | Enum.map(1..12, &"g#{&1}")]})

      assert length(snapshot.genres) == 10
      assert [first, "g1" | _] = snapshot.genres
      assert String.length(first) == 512
    end

    test "still refuses a snapshot without its required keys" do
      assert {:error, :invalid} = Protocol.snapshot(%{"seq" => 1, "snapshot" => %{"running" => true}})
    end
  end

  describe "playback_state/1" do
    test "turns a snapshot into the playback state" do
      assert %PlaybackState{is_playing: true, progress_ms: 12_345, device: %{is_active: true}, status: :normal} =
               state = Protocol.playback_state(snapshot())

      assert %{uri: @uri, name: "Song", duration_ms: 215_000, artists: [%{name: "Artist"}], type: :album} = state.item
      assert state.item.album.name == "Album"
    end

    test "carries the track number and the album track count" do
      state = Protocol.playback_state(snapshot(%{"track_number" => 3, "album_track_count" => 12}))

      assert %{track_number: 3, album: %{name: "Album", total_tracks: 12, images: []}} = state.item
    end

    test "uses 0 tracks for an album whose size is unknown" do
      state = Protocol.playback_state(snapshot())

      assert %{track_number: nil, album: %{total_tracks: 0}} = state.item
    end

    test "is paused when the playback is not playing" do
      assert %PlaybackState{is_playing: false} = Protocol.playback_state(snapshot(%{"playback" => "paused"}))
      assert %PlaybackState{is_playing: false} = Protocol.playback_state(snapshot(%{"playback" => "stopped"}))
    end

    test "has no device when Spotify is not running" do
      assert %PlaybackState{device: nil} = Protocol.playback_state(snapshot(%{"running" => false}))
    end

    test "has the default item when the track is unknown" do
      state = Protocol.playback_state(snapshot(%{"uri" => nil}))

      assert state.item == PlaybackState.default().item
    end

    test "gives a track of unknown length a duration of 1 ms" do
      assert %{item: %{duration_ms: 1}} = Protocol.playback_state(snapshot(%{"length_ms" => 0}))
    end

    test "reads a snapshot of a player that does not send the extras" do
      legacy = Map.drop(snapshot(), [:album_artist, :track_number, :album_track_count, :genres, :shuffle, :repeat])

      assert %{item: %{track_number: nil, album: %{total_tracks: 0}}} = Protocol.playback_state(legacy)
    end
  end

  describe "session/1" do
    test "encodes a running album session with its position" do
      summary = %{state: :active, source: :album, title: "Plantation Lullabies", track_number: 4, track_count: 10}

      assert Protocol.session(summary) == %{
               "state" => "active",
               "source" => "album",
               "name" => "Plantation Lullabies",
               "track_number" => 4,
               "track_count" => 10
             }
    end

    test "encodes a prepared session" do
      summary = %{state: :preparing, source: :playlist, title: "Mix", track_number: nil, track_count: nil}

      assert %{"state" => "preparing", "source" => "playlist", "track_number" => nil, "track_count" => nil} =
               Protocol.session(summary)
    end

    test "encodes no session with only a state" do
      summary = %{state: :none, source: nil, title: nil, track_number: nil, track_count: nil}

      assert Protocol.session(summary) == %{
               "state" => "none",
               "source" => nil,
               "name" => nil,
               "track_number" => nil,
               "track_count" => nil
             }
    end

    test "cuts a long name to 512 characters" do
      summary = %{state: :active, source: :free, title: String.duplicate("é", 600), track_number: nil, track_count: nil}

      assert String.length(Protocol.session(summary)["name"]) == 512
    end
  end
end
