defmodule PremiereEcouteWeb.SessionsChannelTest do
  use PremiereEcouteWeb.ChannelCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    {:ok, _, socket} =
      PremiereEcouteWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(PremiereEcouteWeb.SessionsChannel, "sessions:lobby")

    user = user_fixture(%{role: :streamer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
    {:ok, session} = ListeningSession.start(session)
    {:ok, session} = ListeningSession.next_track(session)

    {:ok, %{socket: socket, session: session}}
  end

  describe "push - get_sessions" do
    test "get_sessions replies with the list of active listening sessions", %{socket: socket} do
      ref = push(socket, "get_sessions", %{})
      assert_reply ref, :ok, %{"data" => [session]}

      assert %{
               "album" => %{
                 "artist" => "Sample Artist",
                 "cover_url" => "http://example.com/cover.jpg",
                 "id" => _,
                 "name" => "Sample Album",
                 "release_date" => "2023-01-01",
                 "total_tracks" => 2,
                 "tracks" => [
                   %{"id" => _, "name" => "Track One", "track_number" => 1},
                   %{"id" => _, "name" => "Track Two", "track_number" => 2}
                 ]
               },
               "current_track" => %{"id" => _, "name" => "Track One", "track_number" => 1},
               "ended_at" => nil,
               "id" => _,
               "started_at" => _,
               "status" => "active",
               "user" => %{
                 "email" => _,
                 "id" => _,
                 "role" => "streamer"
               }
             } = Jason.decode!(session)
    end
  end
end
