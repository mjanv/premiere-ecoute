defmodule PremiereEcoute.Apis.TwitchApi.ChatTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

  setup do
    scope =
      user_scope_fixture(
        user_fixture(%{
          twitch_user_id: "141981764",
          twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
        })
      )

    {:ok, %{scope: scope}}
  end

  describe "send_chat_message/2" do
    test "can send a message to a chat", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/chat/messages"},
        request: "twitch_api/chat/send_chat_message/request.json",
        response: "twitch_api/chat/send_chat_message/response.json",
        status: 200
      )

      message = "Hello, world! twitchdevHype"

      {:ok, message} = TwitchApi.send_chat_message(scope, message)

      assert message == %{
               "message_id" => "abc-123-def",
               "is_sent" => true
             }
    end
  end

  describe "send_announcement/3" do
    test "can send an annoucement to a chat", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/chat/announcements"},
        request: "twitch_api/chat/send_chat_announcement/request.json",
        params: %{"broadcaster_id" => "141981764", "moderator_id" => "141981764"},
        status: 204
      )

      message = "Hello chat!"
      color = "purple"

      {:ok, message} = TwitchApi.send_chat_announcement(scope, message, color)

      assert message == "Hello chat!"
    end
  end
end
