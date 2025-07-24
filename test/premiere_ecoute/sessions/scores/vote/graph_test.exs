defmodule PremiereEcoute.Sessions.Scores.Vote.GraphTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcoute.Sessions.Scores.Vote.Graph

  setup do
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{streamer_id: "streamer", album_id: album.id})

    [track1, track2] = album.tracks
    base_time = ~U[2024-01-01 12:00:00Z]

    create_vote(session.id, track1.id, "alice", "8", DateTime.add(base_time, 3, :second))
    create_vote(session.id, track1.id, "bob", "7", DateTime.add(base_time, 12, :second))
    create_vote(session.id, track1.id, "charlie", "9", DateTime.add(base_time, 18, :second))
    create_vote(session.id, track1.id, "dave", "6", DateTime.add(base_time, 27, :second))
    create_vote(session.id, track1.id, "eve", "8", DateTime.add(base_time, 34, :second))
    create_vote(session.id, track1.id, "frank", "7", DateTime.add(base_time, 41, :second))
    create_vote(session.id, track1.id, "grace", "9", DateTime.add(base_time, 55, :second))
    create_vote(session.id, track1.id, "henry", "5", DateTime.add(base_time, 63, :second))
    create_vote(session.id, track1.id, "iris", "8", DateTime.add(base_time, 72, :second))
    create_vote(session.id, track1.id, "jack", "7", DateTime.add(base_time, 89, :second))

    create_vote(session.id, track2.id, "alice", "6", DateTime.add(base_time, 97, :second))
    create_vote(session.id, track2.id, "bob", "9", DateTime.add(base_time, 108, :second))
    create_vote(session.id, track2.id, "charlie", "8", DateTime.add(base_time, 124, :second))
    create_vote(session.id, track2.id, "dave", "7", DateTime.add(base_time, 135, :second))
    create_vote(session.id, track2.id, "eve", "5", DateTime.add(base_time, 147, :second))
    create_vote(session.id, track2.id, "frank", "9", DateTime.add(base_time, 156, :second))
    create_vote(session.id, track2.id, "grace", "8", DateTime.add(base_time, 171, :second))
    create_vote(session.id, track2.id, "henry", "6", DateTime.add(base_time, 188, :second))
    create_vote(session.id, track2.id, "iris", "7", DateTime.add(base_time, 203, :second))
    create_vote(session.id, track2.id, "jack", "8", DateTime.add(base_time, 219, :second))

    {:ok, %{session: session}}
  end

  describe "rolling_average/1" do
    test "compute a rolling average graph where each new vote update the average", %{session: session} do
      rolling_avg = Graph.rolling_average(session.id)

      assert rolling_avg == [
               {~N[2024-01-01 12:00:03], 8.0},
               {~N[2024-01-01 12:00:12], 7.5},
               {~N[2024-01-01 12:00:18], 8.0},
               {~N[2024-01-01 12:00:27], 7.5},
               {~N[2024-01-01 12:00:34], 7.6},
               {~N[2024-01-01 12:00:41], 7.5},
               {~N[2024-01-01 12:00:55], 7.7},
               {~N[2024-01-01 12:01:03], 7.4},
               {~N[2024-01-01 12:01:12], 7.4},
               {~N[2024-01-01 12:01:29], 7.4},
               {~N[2024-01-01 12:01:37], 7.3},
               {~N[2024-01-01 12:01:48], 7.4},
               {~N[2024-01-01 12:02:04], 7.5},
               {~N[2024-01-01 12:02:15], 7.4},
               {~N[2024-01-01 12:02:27], 7.3},
               {~N[2024-01-01 12:02:36], 7.4},
               {~N[2024-01-01 12:02:51], 7.4},
               {~N[2024-01-01 12:03:08], 7.3},
               {~N[2024-01-01 12:03:23], 7.3},
               {~N[2024-01-01 12:03:39], 7.4}
             ]
    end

    test "compute a rolling average graph where vote are aggregated each minute", %{session: session} do
      rolling_avg = Graph.rolling_average(session.id, :minute)

      assert rolling_avg == [
               {~N[2024-01-01 12:01:00], 7.7},
               {~N[2024-01-01 12:02:00], 7.4},
               {~N[2024-01-01 12:03:00], 7.4},
               {~N[2024-01-01 12:04:00], 7.4}
             ]
    end
  end

  # Helper function to create and persist a vote with specific timestamp
  defp create_vote(session_id, track_id, viewer_id, value, timestamp) do
    %Vote{}
    |> Vote.changeset(%{
      session_id: session_id,
      track_id: track_id,
      viewer_id: viewer_id,
      value: value,
      is_streamer: false
    })
    |> Ecto.Changeset.put_change(:inserted_at, timestamp)
    |> Ecto.Changeset.put_change(:updated_at, timestamp)
    |> Repo.insert!()
  end
end
