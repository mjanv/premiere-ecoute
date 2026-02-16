defmodule PremiereEcoute.Apis.Streaming.TwitchApi.ChatTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    user = user_fixture(%{twitch: %{user_id: "141981764", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}})
    bot = user_fixture(%{twitch: %{user_id: "467189141", access_token: "access_token"}})

    scope = user_scope_fixture(user)
    Cache.put(:users, :bot, bot)

    start_supervised(PremiereEcoute.Apis.RateLimit)
    start_supervised(PremiereEcoute.Apis.Streaming.TwitchQueue)

    :timer.sleep(500)

    {:ok, %{scope: scope}}
  end

  describe "send_chat_message/3" do
    test "can send a message to a chat", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/chat/messages"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/chat/send_chat_message/request.json",
        response: "twitch_api/chat/send_chat_message/response.json",
        status: 200
      )

      message = "Hello, world! twitchdevHype"

      :ok = TwitchApi.send_chat_message(scope, message)

      :timer.sleep(100)
    end
  end

  describe "send_reply_message/3" do
    test "can send a reply message to a chat message", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/chat/messages"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/chat/send_reply_message/request.json",
        response: "twitch_api/chat/send_reply_message/response.json",
        status: 200
      )

      message = "Hello, world! twitchdevHype"
      reply_to = "e8ee4b0d-601a-4fe8-b17f-c7305216e4b1"

      :ok = TwitchApi.send_reply_message(scope, message, reply_to)

      :timer.sleep(100)
    end
  end

  describe "send_announcement/3" do
    test "can send an annoucement to a chat", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/chat/announcements"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/chat/send_chat_announcement/request.json",
        params: %{"broadcaster_id" => "141981764", "moderator_id" => "467189141"},
        status: 204
      )

      message = "Hello chat!"
      color = "purple"

      :ok = TwitchApi.send_chat_announcement(scope, message, color)

      :timer.sleep(100)
    end
  end
end
