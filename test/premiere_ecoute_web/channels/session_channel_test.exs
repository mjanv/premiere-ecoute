defmodule PremiereEcouteWeb.SessionChannelTest do
  use PremiereEcouteWeb.ChannelCase

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcouteCore.Cache

  setup do
    start_supervised(PremiereEcoute.Sessions.Scores.MessagePipeline)

    user = user_fixture(%{role: :streamer, twitch: %{user_id: unique_user_id()}, spotify: %{user_id: unique_user_id()}})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
    {:ok, session} = ListeningSession.start(session)
    {:ok, session} = ListeningSession.next_track(session)

    Cache.put(:sessions, user.twitch.user_id, Map.take(session, [:id, :vote_options, :current_track_id]))

    {:ok, _, socket} =
      PremiereEcouteWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(PremiereEcouteWeb.SessionChannel, "session:#{session.id}")

    {:ok, %{socket: socket, session: session, user: user}}
  end

  describe "push - vote" do
    test "receive current score when a new vote is casted to the active listening session", %{user: user} do
      messages = [
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer01", message: "5", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer02", message: "0", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer03", message: "5", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer04", message: "4", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer05", message: "3", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer06", message: "5", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer07", message: "2", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer08", message: "5", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer09", message: "8", is_streamer: false},
        %MessageSent{broadcaster_id: user.twitch.user_id, user_id: "viewer10", message: "5", is_streamer: false}
      ]

      for message <- messages do
        Sessions.publish_message(message)
      end

      assert_push "session_summary", %{"viewer_score" => 4.2}, 1_000
    end
  end
end
