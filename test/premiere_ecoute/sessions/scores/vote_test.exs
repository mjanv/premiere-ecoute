defmodule PremiereEcoute.Sessions.Scores.VoteTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  setup do
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{streamer_id: "streamer", album_id: album.id})

    {:ok, %{album: album, session: session}}
  end

  describe "create/1" do
    test "create a viewer vote", %{album: album, session: session} do
      attrs = %Vote{
        viewer_id: "twitch_user_42",
        session_id: session.id,
        track_id: hd(album.tracks).id,
        value: "smash",
        is_streamer: false
      }

      {:ok, %Vote{} = vote} = Vote.create(attrs)

      assert %Vote{
               value: "smash",
               is_streamer: false,
               session_id: session_id,
               viewer_id: "twitch_user_42",
               track_id: track_id
             } = vote

      assert session_id == session.id
      assert track_id == attrs.track_id
    end

    test "create a streamer vote", %{album: album, session: session} do
      attrs = %Vote{
        viewer_id: "twitch_streamer_42",
        session_id: session.id,
        track_id: hd(album.tracks).id,
        value: "3",
        is_streamer: true
      }

      {:ok, %Vote{} = vote} = Vote.create(attrs)

      assert %Vote{
               value: "3",
               is_streamer: true,
               session_id: session_id,
               viewer_id: "twitch_streamer_42",
               track_id: track_id
             } = vote

      assert track_id == attrs.track_id
      assert session_id == attrs.session_id
    end
  end

  describe "update/1" do
    test "update an existing vote", %{album: album, session: session} do
      attrs = %Vote{
        viewer_id: "twitch_user_42",
        session_id: session.id,
        track_id: hd(album.tracks).id,
        value: "2",
        is_streamer: false
      }

      {:ok, %Vote{} = vote} = Vote.create(attrs)
      {:ok, %Vote{} = new_vote} = Vote.update(vote, %{value: "3"})

      assert {vote.value, new_vote.value} == {"2", "3"}
    end
  end

  describe "get_by/1" do
    test "get an existing viewer vote", %{album: album, session: session} do
      attrs = %Vote{
        viewer_id: "twitch_user_42",
        session_id: session.id,
        track_id: hd(album.tracks).id,
        value: "2",
        is_streamer: false
      }

      {:ok, _} = Vote.create(attrs)

      vote =
        Vote.get_by(
          viewer_id: attrs.viewer_id,
          session_id: attrs.session_id,
          track_id: attrs.track_id
        )

      assert %Vote{
               value: "2",
               is_streamer: false,
               viewer_id: "twitch_user_42"
             } = vote
    end

    test "does not get an unknown viewer vote" do
      vote = Vote.get_by(viewer_id: "unknown")

      assert is_nil(vote)
    end
  end

  describe "all/1" do
    test "read all votes from a listening session", %{album: album, session: session} do
      %ListeningSession{id: id} = session
      %Album{tracks: [%Track{id: t1_id}, %Track{id: t2_id}]} = album

      votes = [
        %Vote{viewer_id: "1", session_id: id, track_id: t1_id, is_streamer: true, value: "1"},
        %Vote{viewer_id: "1", session_id: id, track_id: t2_id, is_streamer: true, value: "2"},
        %Vote{viewer_id: "2", session_id: id, track_id: t1_id, is_streamer: false, value: "0"},
        %Vote{viewer_id: "2", session_id: id, track_id: t2_id, is_streamer: false, value: "1"}
      ]

      for vote <- votes do
        {:ok, _} = Vote.create(vote)
      end

      registered_votes = Vote.all(where: [session_id: id])

      assert [
               %Vote{
                 viewer_id: "1",
                 session_id: ^id,
                 track_id: ^t1_id,
                 is_streamer: true,
                 value: "1"
               },
               %Vote{
                 viewer_id: "1",
                 session_id: ^id,
                 track_id: ^t2_id,
                 is_streamer: true,
                 value: "2"
               },
               %Vote{
                 viewer_id: "2",
                 session_id: ^id,
                 track_id: ^t1_id,
                 is_streamer: false,
                 value: "0"
               },
               %Vote{
                 viewer_id: "2",
                 session_id: ^id,
                 track_id: ^t2_id,
                 is_streamer: false,
                 value: "1"
               }
             ] = registered_votes
    end
  end
  
  describe "from_message/2" do
    test "can accept messages from a list" do
      
      {:ok, value} = Vote.from_message("5", ["5"])
      
      assert value == "5"
    end
    
    test "can refuse messages from a list" do
      
      {:error, value} = Vote.from_message("6", ["5"])
      
      assert value == "6"
    end
  end
end
