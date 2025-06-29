defmodule PremiereEcoute.Sessions.Scores.VoteTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Track
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  @album %Album{
    spotify_id: "album123",
    name: "Sample Album",
    artist: "Sample Artist",
    release_date: ~D[2023-01-01],
    cover_url: "http://example.com/cover.jpg",
    total_tracks: 2,
    tracks: [
      %Track{
        spotify_id: "track001",
        name: "Track One",
        track_number: 1,
        duration_ms: 210_000
      },
      %Track{
        spotify_id: "track002",
        name: "Track Two",
        track_number: 2,
        duration_ms: 180_000
      }
    ]
  }

  setup do
    {:ok, album} = Album.create(@album)
    {:ok, session} = ListeningSession.create(%{streamer_id: "streamer", album_id: album.id})

    {:ok, %{album: album, session: session}}
  end

  describe "add_vote/1" do
    test "add a viewer vote", %{album: album, session: session} do
      attrs = %Vote{
        viewer_id: "twitch_user_42",
        session_id: session.id,
        track_id: hd(album.tracks).id,
        value: 2,
        streamer?: false
      }

      {:ok, %Vote{} = vote} = Vote.add(attrs)

      assert %Vote{
               value: 2,
               streamer?: false,
               session_id: 1,
               viewer_id: "twitch_user_42",
               track_id: 1
             } = vote
    end

    test "add a streamer vote", %{album: album, session: session} do
      attrs = %Vote{
        viewer_id: "twitch_streamer_42",
        session_id: session.id,
        track_id: hd(album.tracks).id,
        value: 3,
        streamer?: true
      }

      {:ok, %Vote{} = vote} = Vote.add(attrs)

      assert %Vote{
               value: 3,
               streamer?: true,
               session_id: 1,
               viewer_id: "twitch_streamer_42",
               track_id: 1
             } = vote
    end
  end

  describe "listening_session_votes/1" do
    test "read all votes from a listening sessions", %{album: album, session: session} do
      %ListeningSession{id: s_id} = session
      %Album{tracks: [%Track{id: t1_id}, %Track{id: t2_id}]} = album

      votes = [
        %Vote{viewer_id: "1", session_id: s_id, track_id: t1_id, streamer?: true, value: 1},
        %Vote{viewer_id: "1", session_id: s_id, track_id: t2_id, streamer?: true, value: 2},
        %Vote{viewer_id: "2", session_id: s_id, track_id: t1_id, streamer?: false, value: 0},
        %Vote{viewer_id: "2", session_id: s_id, track_id: t2_id, streamer?: false, value: 1}
      ]

      for vote <- votes do
        {:ok, _} = Vote.add(vote)
      end

      registered_votes = Vote.listening_session_votes(s_id)

      assert [
               %Vote{
                 viewer_id: "1",
                 session_id: ^s_id,
                 track_id: ^t1_id,
                 streamer?: true,
                 value: 1
               },
               %Vote{
                 viewer_id: "1",
                 session_id: ^s_id,
                 track_id: ^t2_id,
                 streamer?: true,
                 value: 2
               },
               %Vote{
                 viewer_id: "2",
                 session_id: ^s_id,
                 track_id: ^t1_id,
                 streamer?: false,
                 value: 0
               },
               %Vote{
                 viewer_id: "2",
                 session_id: ^s_id,
                 track_id: ^t2_id,
                 streamer?: false,
                 value: 1
               }
             ] = registered_votes
    end
  end
end
