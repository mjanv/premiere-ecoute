defmodule PremiereEcoute.Sessions.Scores.CommandHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Commands.Chat.SendChatCommand
  alias PremiereEcoute.Sessions.Scores.CommandHandler
  alias PremiereEcouteCore.CommandBus

  alias PremiereEcoute.Apis.TwitchApi.Mock, as: TwitchApi

  describe "handle/1 - SendChatCommand with hello" do
    test "successfully sends hello reply when broadcaster exists" do
      broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "token"}})

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "cc106a89-1814-919d-454c-f4f2f970aae7",
        command: "hello",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert scope.user.twitch.user_id == "1971641"
        assert message == "Hello!"
        assert reply_to == "cc106a89-1814-919d-454c-f4f2f970aae7"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "returns error when broadcaster not found" do
      command = %SendChatCommand{
        broadcaster_id: "nonexistent",
        user_id: "4145994",
        message_id: "msg-123",
        command: "hello",
        args: [],
        is_streamer: false
      }

      assert {:error, []} = CommandBus.apply(command)
    end

    test "handles unknown commands with fallback" do
      # AIDEV-NOTE: Unknown commands are handled by the catch-all handle/1 clause
      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "msg-123",
        command: "unknown",
        args: [],
        is_streamer: false
      }

      # Should not call send_reply_message for unknown commands
      assert {:ok, []} = CommandBus.apply(command)
    end

    test "handles hello command with different broadcaster" do
      broadcaster = user_fixture(%{twitch: %{user_id: "9999999", access_token: "token2"}})

      command = %SendChatCommand{
        broadcaster_id: "9999999",
        user_id: "1111111",
        message_id: "another-msg-id",
        command: "hello",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert scope.user.twitch.user_id == "9999999"
        assert message == "Hello!"
        assert reply_to == "another-msg-id"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "ignores command arguments for hello command" do
      broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "token"}})

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "msg-123",
        command: "hello",
        args: ["extra", "arguments", "ignored"],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert message == "Hello!"
        assert reply_to == "msg-123"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end
  end

  describe "handle/1 - fallback" do
    test "returns ok for unhandled commands after validation fails" do
      # This tests the catch-all handle/1 clause
      # Note: This would normally not be reached in practice since validate
      # would reject unknown commands first
      assert {:ok, []} = CommandHandler.handle(%{})
    end
  end
end
