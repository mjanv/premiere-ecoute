defmodule PremiereEcoute.Wrapped.ListensTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Wrapped.Listen
  alias PremiereEcoute.Wrapped.Listens

  @year Date.utc_today().year

  setup do
    {:ok, streamer: user_fixture(%{role: :streamer}), viewer: user_fixture(%{twitch: %{user_id: "viewer1"}})}
  end

  defp albums(viewer, year \\ @year), do: viewer |> Listens.all(year) |> Listen.albums()
  defp tracks(viewer), do: viewer |> Listens.all(@year) |> Listen.tracks() |> Enum.sort_by(&Listen.name/1)

  describe "all/2, albums" do
    test "lists one listen per album with its domain album", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8", "6"], others: [{"viewer2", "4"}])

      assert [%Listen{entity: %Album{name: "Album 1"}, result: result} = listen] = albums(viewer)
      assert %{score: 7.0, chat_score: 5.5} = result
      assert result.streamers == [streamer.username]

      assert {Listen.artist(listen), Listen.opening_track(listen), Listen.duration_ms(listen)} ==
               {"Sample Artist", "Track One", 390_000}
    end

    test "averages the track votes of a session", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8", "5"])
      listened(streamer, 2, ["7", "8"])

      assert [%{result: %{score: 6.5}}, %{result: %{score: 7.5}}] = albums(viewer) |> Enum.sort_by(&Listen.name/1)
    end

    test "prefers the album vote to the track votes", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["2", "4"], album: "9")

      assert [%{result: %{score: 9.0, chat_score: 9.0}}] = albums(viewer)
      assert [%{result: %{score: 2.0}}, %{result: %{score: 4.0}}] = tracks(viewer)
    end

    test "brings a 1 to 5 scale to /10 from its highest option", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["1", "5"], vote_options: ListeningSession.vote_options("1-5"))

      assert [%{result: %{score: 6.0}}] = albums(viewer)
      # Pins current behaviour: the lowest option of a 1 to 5 scale is worth 2/10, not 0
      assert [%{result: %{score: 2.0}}, %{result: %{score: 10.0}}] = tracks(viewer)
    end

    test "keeps a vote of zero", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["0"])

      assert [%{result: %{score: album_score}}] = albums(viewer)
      assert [%{result: %{score: track_score}}] = tracks(viewer)
      assert {album_score, track_score} == {0.0, 0.0}
    end

    test "keeps an album voted on a text scale, without score nor track", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["smash"], vote_options: ListeningSession.vote_options("smash-pass"))

      assert [%Listen{entity: %Album{name: "Album 1"}, result: %{score: nil, chat_score: nil}}] = Listens.all(viewer, @year)
    end

    test "gives no score on a numeric scale that does not fit on /10", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["67"], vote_options: ["6", "7", "67"])

      assert [%Listen{entity: %Album{}, result: %{score: nil}}] = Listens.all(viewer, @year)
    end

    test "gives no chat score to a session without report", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], report: false)

      assert [%{result: %{score: 8.0, chat_score: nil}}] = albums(viewer)
      assert [%{result: %{score: 8.0, chat_score: nil}}] = tracks(viewer)
    end

    test "counts private sessions", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], visibility: :private)

      assert [%{result: %{score: 8.0}}] = albums(viewer)
    end

    test "counts votes cast as a streamer, which the chat average leaves out", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], is_streamer: true, others: [{"viewer2", "4"}])

      assert [%{result: %{score: 8.0, chat_score: 4.0}}] = albums(viewer)
    end
  end

  describe "all/2, an album played in several sessions" do
    test "merges the sessions into one listen", %{streamer: streamer, viewer: viewer} do
      other = user_fixture(%{role: :streamer})
      album = listened(streamer, 1, ["10", "10"], voted_at: ~U[2026-03-10 20:00:00Z], others: [{"viewer2", "6"}])
      listened(other, album, ["4"], voted_at: ~U[2026-02-01 20:00:00Z])

      assert [%Listen{result: result} = listen] = albums(viewer, 2026)
      # The mean of the two session scores (10 and 4), not of the three votes
      assert result.score == 7.0
      assert result.chat_score == 6.0
      assert result.voted_at == ~U[2026-02-01 20:00:00Z]
      assert Enum.sort(result.streamers) == Enum.sort([streamer.username, other.username])
      assert {Listen.sessions(listen), Listen.duration_ms(listen)} == {2, 780_000}
    end

    test "names the streamer once per session", %{streamer: streamer, viewer: viewer} do
      album = listened(streamer, 1, ["8"])
      listened(streamer, album, ["6"])

      assert [%{result: %{score: 7.0, streamers: [name, name]}}] = albums(viewer)
      assert name == streamer.username
    end

    test "ignores the sessions without score in the mean", %{streamer: streamer, viewer: viewer} do
      album = listened(streamer, 1, ["8"])
      listened(streamer, album, ["smash"], vote_options: ListeningSession.vote_options("smash-pass"))

      assert [%{result: %{score: 8.0, chat_score: 8.0}} = listen] = albums(viewer)
      assert Listen.sessions(listen) == 2
    end

    # Pins current behaviour: a track rated in two sessions gives two track listens, not one merged listen
    test "lists a track once per session it was rated in", %{streamer: streamer, viewer: viewer} do
      album = listened(streamer, 1, ["8"])
      listened(streamer, album, ["6"])

      assert [%{entity: %Track{name: "Track One"}}, %{entity: %Track{name: "Track One"}}] = tracks(viewer)
      assert viewer |> tracks() |> Enum.map(& &1.result.score) |> Enum.sort() == [6.0, 8.0]
    end
  end

  describe "all/2, tracks" do
    test "lists one listen per rated track, with its album and the chat average", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8", "6"], others: [{"viewer2", "4"}])

      assert [one, two] = tracks(viewer)

      assert %Listen{entity: %Track{name: "Track One", album: %Album{name: "Album 1"}}, result: %{score: 8.0, chat_score: 6.0}} =
               one

      assert %Listen{entity: %Track{name: "Track Two"}, result: %{score: 6.0, chat_score: 5.0}} = two
      assert one.result.streamers == [streamer.username]
      assert {Listen.artist(one), Listen.cover_url(one)} == {"Sample Artist", one.entity.album.cover_url}
    end

    test "lists only the tracks the viewer rated", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"])

      assert [%{entity: %Track{name: "Track One"}}] = tracks(viewer)
    end

    test "lists no track for an album vote alone", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, [], album: "9")

      assert [%Listen{entity: %Album{}, result: %{score: 9.0}}] = Listens.all(viewer, @year)
    end
  end

  describe "all/2, singles" do
    test "lists one listen per single", %{streamer: streamer, viewer: viewer} do
      listened_single(streamer, 1, "8", others: [{"viewer2", "4"}])
      listened_single(streamer, 2, "3")

      assert [one, two] = viewer |> Listens.all(@year) |> Listen.singles() |> Enum.sort_by(&Listen.name/1)
      assert %Listen{entity: %Single{name: "Single 1"}, result: %{score: 8.0, chat_score: 6.0}} = one
      assert {Listen.artist(one), Listen.cover_url(one)} == {"Sample Artist", "http://example.com/cover.jpg"}
      assert %Listen{entity: %Single{name: "Single 2"}, result: %{score: 3.0}} = two
    end

    test "merges the sessions of a single", %{streamer: streamer, viewer: viewer} do
      single = listened_single(streamer, 1, "10")
      listened_single(streamer, single, "4")

      assert [%Listen{entity: %Single{}, result: %{score: 7.0, streamers: [_, _]}}] = Listens.all(viewer, @year)
    end
  end

  describe "all/2, whose votes and when" do
    test "sorts every listen by first vote", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], voted_at: ~U[2026-05-05 20:00:00Z])
      listened_single(streamer, 1, "8", voted_at: ~U[2026-01-01 20:00:00Z])
      listened(streamer, 2, [], album: "5", voted_at: ~U[2026-03-03 20:00:00Z])

      assert viewer |> Listens.all(2026) |> Enum.map(&Listen.name/1) == ["Single 1", "Album 2", "Album 1", "Track One"]
    end

    test "counts a vote in the UTC year it was cast in", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], voted_at: ~U[2025-12-31 23:59:59Z])
      listened(streamer, 2, ["8"], voted_at: ~U[2026-01-01 00:00:00Z])

      assert [%{entity: %Album{name: "Album 1"}}] = albums(viewer, 2025)
      assert [%{entity: %Album{name: "Album 2"}}] = albums(viewer, 2026)
      assert Listens.all(viewer, 2027) == []
    end

    test "ignores the votes of other viewers", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"], viewer: "viewer2")

      assert Listens.all(viewer, @year) == []
      assert [_, _] = Listens.all(user_fixture(%{twitch: %{user_id: "viewer2"}}), @year)
    end

    test "lists nothing for a user without Twitch account", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"])

      assert Listens.all(%{viewer | twitch: nil}, @year) == []
      assert Listens.all(%{viewer | twitch: %{viewer.twitch | user_id: nil}}, @year) == []
      assert Listens.all(streamer, @year) == []
    end
  end
end
