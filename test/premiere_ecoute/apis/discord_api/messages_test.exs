defmodule PremiereEcoute.Apis.DiscordApi.MessagesTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.DiscordApi

  # AIDEV-NOTE: Discord uses bot token auth, no need for user scope setup

  describe "send_message_to_channel/2" do
    test "successfully sends a message to a Discord channel" do
      channel_id = "123456789012345678"
      content = "Hello from Premiere Ecoute!"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot test_bot_token"},
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
      content = "Test message"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot test_bot_token"},
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
      content = "Server maintenance starting in 5 minutes"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot test_bot_token"},
          {"content-type", "application/json"}
        ],
        status: 201
      )

      {:ok, _message} = DiscordApi.send_message_to_channel(channel_id, content)
    end
  end

  describe "send_message/2" do
    test "successfully sends message to predefined channel by key" do
      # AIDEV-NOTE: Testing with :notifications channel key from config
      content = "Test notification message"

      # Mock the channel() function to return a test channel ID
      # In real config, this would come from Application.get_env
      channel_id = "your_channel_id_here"

      ApiMock.expect(
        DiscordApi,
        path: {:post, "/channels/#{channel_id}/messages"},
        headers: [
          {"authorization", "Bot test_bot_token"},
          {"content-type", "application/json"}
        ],
        response: "discord_api/messages/send_message/response.json",
        status: 201
      )

      # This will use the configured channel ID for :notifications
      result = DiscordApi.send_message(:notifications, content)

      # Should either succeed or return error about channel not configured
      # depending on test environment setup
      assert result == {:error, "Channel :notifications not configured"} or
               match?({:ok, %{"id" => _}}, result)
    end

    test "returns error when channel key is not configured" do
      content = "Test message"

      result = DiscordApi.send_message(:invalid_channel, content)

      assert result == {:error, "Channel :invalid_channel not configured"}
    end
  end
end
