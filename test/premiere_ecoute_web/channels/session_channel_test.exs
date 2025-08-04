defmodule PremiereEcouteWeb.SessionChannelTest do
  use PremiereEcouteWeb.ChannelCase

  alias PremiereEcoute.Core.EventBus
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Events.MessageSent

  setup do
    user = user_fixture(%{role: :streamer, twitch: %{user_id: unique_user_id()}, spotify: %{user_id: unique_user_id()}})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
    {:ok, session} = ListeningSession.start(session)
    {:ok, session} = ListeningSession.next_track(session)

    {:ok, _, socket} =
      PremiereEcouteWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(PremiereEcouteWeb.SessionChannel, "session:#{session.id}")

    {:ok, %{socket: socket, session: session, user: user}}
  end

  describe "push - vote" do
    test "receive current score when a new vote is casted to the active listening session", %{user: user} do
      EventBus.dispatch(%MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer1", message: "5", is_streamer: false})
      EventBus.dispatch(%MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer2", message: "10", is_streamer: false})

      assert_push "session_summary", %{"viewer_score" => 5.0}, 1_000
      assert_push "session_summary", %{"viewer_score" => 7.5}, 1_000
    end
  end
end
