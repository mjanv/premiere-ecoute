defmodule PremiereEcoute.Sessions.Scores.PollTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Poll

  setup do
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{streamer_id: "streamer", album_id: album.id})

    {:ok, %{album: album, session: session}}
  end

  describe "create/1" do
    test "create a poll", %{album: album, session: session} do
      attrs = %Poll{
        poll_id: "poll_id",
        title: "Poll question ?",
        total_votes: 8,
        votes: %{1 => 3, 2 => 5},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:ok, %Poll{} = poll} = Poll.create(attrs)

      assert %Poll{
               poll_id: "poll_id",
               session_id: session_id,
               title: "Poll question ?",
               votes: %{1 => 3, 2 => 5},
               track_id: track_id
             } = poll

      assert session_id == session.id
      assert track_id == attrs.track_id
    end

    test "does not create a poll with wrong votes", %{album: album, session: session} do
      attrs = %Poll{
        poll_id: "poll_id",
        title: "Poll question ?",
        total_votes: 0,
        votes: %{1 => 3, 2 => 5},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:error, changeset} = Poll.create(attrs)

      assert Repo.traverse_errors(changeset) == %{votes: ["vote counts must sum to total_votes"]}
    end
  end

  describe "upsert/1" do
    test "upsert a poll", %{album: album, session: session} do
      attrs = %Poll{
        poll_id: "poll_id",
        title: "Poll question ?",
        total_votes: 8,
        votes: %{"1" => 3, "2" => 5},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:ok, %Poll{} = poll} = Poll.create(attrs)

      attrs = %Poll{
        poll_id: "poll_id",
        total_votes: 9,
        votes: %{"1" => 3, "2" => 6}
      }

      {:ok, %Poll{} = new_poll} = Poll.upsert(attrs)

      assert %Poll{
               poll_id: "poll_id",
               session_id: session_id,
               title: "Poll question ?",
               votes: %{"1" => 3, "2" => 6},
               track_id: track_id
             } = new_poll

      assert session_id == session.id
      assert track_id == poll.track_id
    end

    test "does not upsert a poll with wrong votes", %{album: album, session: session} do
      attrs = %Poll{
        poll_id: "poll_id",
        title: "Poll question ?",
        total_votes: 8,
        votes: %{"1" => 3, "2" => 5},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:ok, %Poll{}} = Poll.create(attrs)

      attrs = %Poll{
        poll_id: "poll_id",
        title: "Poll question ?",
        total_votes: 0,
        votes: %{"1" => 3, "2" => 6},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:error, changeset} = Poll.upsert(attrs)

      assert Repo.traverse_errors(changeset) == %{votes: ["vote counts must sum to total_votes"]}
    end
  end

  describe "get_by/1" do
    test "get a poll by session_id", %{album: album, session: session} do
      attrs = %Poll{
        poll_id: "poll_get_by",
        title: "Get by test",
        total_votes: 5,
        votes: %{1 => 2, 10 => 3},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:ok, _} = Poll.create(attrs)

      poll = Poll.get_by(session_id: session.id)

      assert %Poll{
               poll_id: "poll_get_by",
               title: "Get by test",
               votes: %{"1" => 2, "10" => 3},
               total_votes: 5
             } = poll
    end

    test "returns nil when poll does not exist" do
      poll = Poll.get_by(session_id: 999)

      assert is_nil(poll)
    end
  end

  describe "all/1" do
    test "returns all polls for a session", %{album: album, session: session} do
      track_ids = Enum.map(album.tracks, & &1.id)

      polls = [
        %Poll{
          poll_id: "poll_1",
          session_id: session.id,
          track_id: Enum.at(track_ids, 0),
          votes: %{"1" => 3, "5" => 2},
          total_votes: 5
        },
        %Poll{
          poll_id: "poll_2",
          session_id: session.id,
          track_id: Enum.at(track_ids, 1),
          votes: %{"8" => 1, "10" => 4},
          total_votes: 5
        }
      ]

      for poll <- polls do
        {:ok, _} = Poll.create(poll)
      end

      found_polls = Poll.all(where: [session_id: session.id], order_by: [asc: :poll_id])

      assert length(found_polls) == 2
      assert Enum.all?(found_polls, &(&1.session_id == session.id))
      assert Enum.map(found_polls, & &1.poll_id) == ["poll_1", "poll_2"]
    end

    test "returns empty list when no polls exist for session" do
      polls = Poll.all(where: [session_id: 999])

      assert polls == []
    end
  end
end
