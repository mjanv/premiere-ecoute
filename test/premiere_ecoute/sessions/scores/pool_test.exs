defmodule PremiereEcoute.Sessions.Scores.PoolTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Pool

  setup do
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{streamer_id: "streamer", album_id: album.id})

    {:ok, %{album: album, session: session}}
  end

  describe "create/1" do
    test "create a pool", %{album: album, session: session} do
      attrs = %Pool{
        poll_id: "pool_id",
        title: "Pool question ?",
        total_votes: 8,
        votes: %{1 => 3, 2 => 5},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:ok, %Pool{} = pool} = Pool.create(attrs)

      assert %Pool{
               poll_id: "pool_id",
               session_id: session_id,
               title: "Pool question ?",
               votes: %{1 => 3, 2 => 5},
               track_id: track_id
             } = pool

      assert session_id == session.id
      assert track_id == attrs.track_id
    end

    test "does not create a poll with wrong votes", %{album: album, session: session} do
      attrs = %Pool{
        poll_id: "pool_id",
        title: "Pool question ?",
        total_votes: 0,
        votes: %{1 => 3, 2 => 5},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:error, changeset} = Pool.create(attrs)

      assert Repo.traverse_errors(changeset) == %{votes: ["vote counts must sum to total_votes"]}
    end
  end

  describe "get_by/1" do
    test "get a pool by session_id", %{album: album, session: session} do
      attrs = %Pool{
        poll_id: "pool_get_by",
        title: "Get by test",
        total_votes: 5,
        votes: %{1 => 2, 10 => 3},
        session_id: session.id,
        track_id: hd(album.tracks).id
      }

      {:ok, _} = Pool.create(attrs)

      pool = Pool.get_by(session_id: session.id)

      assert %Pool{
               poll_id: "pool_get_by",
               title: "Get by test",
               votes: %{"1" => 2, "10" => 3},
               total_votes: 5
             } = pool
    end

    test "returns nil when pool does not exist" do
      pool = Pool.get_by(session_id: 999)

      assert is_nil(pool)
    end
  end

  describe "all/1" do
    test "returns all pools for a session", %{album: album, session: session} do
      track_ids = Enum.map(album.tracks, & &1.id)

      pools = [
        %Pool{
          poll_id: "pool_1",
          session_id: session.id,
          track_id: Enum.at(track_ids, 0),
          votes: %{1 => 3, 5 => 2},
          total_votes: 5
        },
        %Pool{
          poll_id: "pool_2",
          session_id: session.id,
          track_id: Enum.at(track_ids, 1),
          votes: %{8 => 1, 10 => 4},
          total_votes: 5
        }
      ]

      for pool <- pools do
        {:ok, _} = Pool.create(pool)
      end

      found_pools = Pool.all(session_id: session.id)

      assert length(found_pools) == 2
      assert Enum.all?(found_pools, &(&1.session_id == session.id))
      assert Enum.map(found_pools, & &1.poll_id) == ["pool_1", "pool_2"]
    end

    test "returns empty list when no pools exist for session" do
      pools = Pool.all(session_id: 999)

      assert pools == []
    end
  end
end
