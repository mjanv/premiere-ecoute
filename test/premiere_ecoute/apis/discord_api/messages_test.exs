defmodule PremiereEcoute.Apis.DiscordApi.MessagesTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.DiscordApi

  setup do
    Application.put_env(:premiere_ecoute, :discord_bot_token, "discord_bot_token")

    :ok
  end

  describe "send_message_to_channel/2" do
    test "successfully sends a message to a Discord channel" do
      channel_id = "123456789012345678"
      content = "Hello from Premiere Ecoute!"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/api/v10/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot discord_bot_token"},
          {"content-type", "application/json"}
        ],
        request: "discord_api/messages/send_message/request.json",
        response: "discord_api/messages/send_message/response.json",
        status: 201
      )

      {:ok, message} = DiscordApi.send_message_to_channel(channel_id, content)

      assert message["id"] == "987654321098765432"
      assert message["content"] == content
      assert message["channel_id"] == channel_id
      assert message["author"]["bot"] == true
    end

    test "handles error when bot lacks permissions" do
      channel_id = "123456789012345678"
      content = "Hello from Premiere Ecoute!"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/api/v10/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot discord_bot_token"},
          {"content-type", "application/json"}
        ],
        request: "discord_api/messages/send_message/request.json",
        response: "discord_api/messages/send_message/error_response.json",
        status: 403
      )

      {:error, reason} = DiscordApi.send_message_to_channel(channel_id, content)

      assert reason =~ "403"
    end

    test "sends message with different content" do
      channel_id = "999888777666555444"
      content = "Hello from Premiere Ecoute!"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/api/v10/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot discord_bot_token"},
          {"content-type", "application/json"}
        ],
        status: 201
      )

      {:ok, _message} = DiscordApi.send_message_to_channel(channel_id, content)
    end
  end

  describe "send_message/2" do
    test "successfully sends message to predefined channel by key" do
      content = "Hello from Premiere Ecoute!"

      result = DiscordApi.send_message(:notifications, content)

      assert result == {:error, "Channel :notifications not configured"}
    end

    test "returns error when channel key is not configured" do
      content = "Test message"

      result = DiscordApi.send_message(:invalid_channel, content)

      assert result == {:error, "Channel :invalid_channel not configured"}
    end
  end
end
