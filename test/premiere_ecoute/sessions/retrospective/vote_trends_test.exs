defmodule PremiereEcoute.Sessions.Retrospective.VoteTrendsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.VoteTrends
  alias PremiereEcoute.Sessions.Scores.Vote

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

    {:ok, %{session: session, tracks: album.tracks}}
  end

  describe "distribution/1" do
    test "compute the distribution of a session", %{session: session} do
      distribution = VoteTrends.distribution(session.id)

      assert distribution == [{"5", 2}, {"6", 3}, {"7", 5}, {"8", 6}, {"9", 4}]
    end
  end

  describe "track_distribution/1" do
    test "compute the track distribution of a session", %{session: session, tracks: tracks} do
      [%{id: id1}, %{id: id2}] = tracks
      distributions = VoteTrends.track_distribution(session.id)

      assert %{
               ^id1 => [{"5", 1}, {"6", 1}, {"7", 3}, {"8", 3}, {"9", 2}],
               ^id2 => [{"5", 1}, {"6", 2}, {"7", 2}, {"8", 3}, {"9", 2}]
             } = distributions
    end
  end

  describe "consensus/1" do
    test "compute rating metrics over session distribution", %{session: session} do
      distribution = VoteTrends.distribution(session.id)

      consensus = VoteTrends.consensus(distribution)

      assert consensus == %{entropy: 1.5684705556118044, mean: 7.28, mode_share: 0.28, score: 6.558750609756243, variance: 1.6416}
    end

    test "compute rating metrics over track distributions", %{session: session, tracks: tracks} do
      [%{id: id1}, %{id: id2}] = tracks
      distributions = VoteTrends.track_distribution(session.id)

      consensus = VoteTrends.consensus(distributions)

      assert %{
               ^id1 => %{
                 mean: 7.266666666666667,
                 variance: 1.6622222222222223,
                 mode_share: 0.26666666666666666,
                 entropy: 1.5641315026219946,
                 score: 6.510728026279086
               },
               ^id2 => %{
                 mean: 7.2,
                 variance: 1.76,
                 mode_share: 0.26666666666666666,
                 entropy: 1.5867847075280475,
                 score: 6.406683417191173
               }
             } = consensus
    end
  end

  describe "rolling_average/1" do
    test "compute a rolling average graph where each new vote update the average", %{session: session} do
      rolling_avg = VoteTrends.rolling_average(session.id)

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
      rolling_avg = VoteTrends.rolling_average(session.id, :minute)

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
