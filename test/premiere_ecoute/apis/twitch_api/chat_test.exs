defmodule PremiereEcoute.Apis.TwitchApi.ChatTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcouteCore.Cache

  setup do
    user = user_fixture(%{twitch: %{user_id: "141981764", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}})
    bot = %User{twitch: %User.OauthToken{user_id: "467189141", access_token: "access_token"}}

    scope = user_scope_fixture(user)
    Cache.put(:users, :bot, bot)

    # Req.Test.set_req_test_to_shared()
    # Req.Test.verify_on_exit!()
    # setup_req_test()

    {:ok, %{scope: scope}}
  end

  describe "send_chat_message/3" do
    test "can send a message to a chat with zero delay", %{scope: scope} do
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

      :ok = TwitchApi.send_chat_message(scope, message, 0)

      :timer.sleep(100)
    end

    test "can send a message to a chat with delay", %{scope: scope} do
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

      :ok = TwitchApi.send_chat_message(scope, message, 50)

      :timer.sleep(100)
    end
  end

  describe "send_chat_messages/3" do
    test "can send multiple messages to a chat with minimal delay", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/chat/messages"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/chat/send_chat_message/request.json",
        response: "twitch_api/chat/send_chat_message/response.json",
        status: 200,
        n: 3
      )

      messages = ["Hello, world! twitchdevHype", "Hello, world! twitchdevHype", "Hello, world! twitchdevHype"]

      :ok = TwitchApi.send_chat_messages(scope, messages, 10)

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

      {:ok, message} = TwitchApi.send_chat_announcement(scope, message, color)

      assert message == "Hello chat!"
    end
  end
end
