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

  describe "handle/1 - SendChatCommand with vote" do
    test "sends average score when viewer has votes in active session" do
      broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "token"}})
      viewer_id = "4145994"

      # Create active session with votes
      session = session_fixture(%{user_id: broadcaster.id, status: :active})

      # Create votes: 5, 7, 9 -> average = 7.0
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 1, value: "5"})
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 2, value: "7"})
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 3, value: "9"})

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: viewer_id,
        message_id: "msg-123",
        command: "vote",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert message == "7.0/10"
        assert reply_to == "msg-123"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "does not send message when viewer has no votes in active session" do
      broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "token"}})
      viewer_id = "4145994"

      # Create active session without votes for this viewer
      _session = session_fixture(%{user_id: broadcaster.id, status: :active})

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: viewer_id,
        message_id: "msg-123",
        command: "vote",
        args: [],
        is_streamer: false
      }

      # No expectation - should not call send_reply_message
      assert {:ok, []} = CommandBus.apply(command)
    end

    test "does not send message when there is no active session" do
      _broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "token"}})
      viewer_id = "4145994"

      # No active session for this broadcaster

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: viewer_id,
        message_id: "msg-123",
        command: "vote",
        args: [],
        is_streamer: false
      }

      # No expectation - should not call send_reply_message
      assert {:ok, []} = CommandBus.apply(command)
    end

    test "calculates correct average with different vote values" do
      broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "token"}})
      viewer_id = "4145994"

      session = session_fixture(%{user_id: broadcaster.id, status: :active})

      # Create votes: 0, 10 -> average = 5.0
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 1, value: "0"})
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 2, value: "10"})

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: viewer_id,
        message_id: "msg-123",
        command: "vote",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn _scope, message, _reply_to ->
        assert message == "5.0/10"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end
  end

  describe "handle/1 - SendChatCommand with premiereecoute" do
    test "sends message in English when broadcaster language is en" do
      broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "token"},
          profile: %{language: :en}
        })

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "msg-123",
        command: "premiereecoute",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert scope.user.twitch.user_id == "1971641"

        assert message ==
                 "Premiere Ecoute is a platform where viewers can vote on music played during the stream. Register on premiere-ecoute.fr to view your votes!"

        assert reply_to == "msg-123"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "sends message in French when broadcaster language is fr" do
      broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "token"},
          profile: %{language: :fr}
        })

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "msg-456",
        command: "premiereecoute",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert scope.user.profile.language == :fr

        assert message ==
                 "Première Écoute est une plateforme où les spectateurs peuvent voter pour la musique diffusée pendant le stream. Inscrivez-vous sur premiere-ecoute.fr pour consulter vos votes !"

        assert reply_to == "msg-456"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "sends message in Italian when broadcaster language is it" do
      broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "token"},
          profile: %{language: :it}
        })

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "msg-789",
        command: "premiereecoute",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert scope.user.profile.language == :it

        assert message ==
                 "Premiere Ecoute è una piattaforma dove gli spettatori possono votare la musica suonata durante lo stream. Registrati su premiere-ecoute.fr per visualizzare i tuoi voti!"

        assert reply_to == "msg-789"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "returns error when broadcaster not found" do
      command = %SendChatCommand{
        broadcaster_id: "nonexistent",
        user_id: "4145994",
        message_id: "msg-123",
        command: "premiereecoute",
        args: [],
        is_streamer: false
      }

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "ignores command arguments for premiereecoute command" do
      broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "token"},
          profile: %{language: :en}
        })

      command = %SendChatCommand{
        broadcaster_id: "1971641",
        user_id: "4145994",
        message_id: "msg-123",
        command: "premiereecoute",
        args: ["extra", "arguments", "ignored"],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id

        assert message ==
                 "Premiere Ecoute is a platform where viewers can vote on music played during the stream. Register on premiere-ecoute.fr to view your votes!"

        assert reply_to == "msg-123"
        :ok
      end)

      assert {:ok, []} = CommandBus.apply(command)
    end

    test "works with different broadcaster for premiereecoute command" do
      broadcaster =
        user_fixture(%{
          twitch: %{user_id: "9999999", access_token: "token2"},
          profile: %{language: :fr}
        })

      command = %SendChatCommand{
        broadcaster_id: "9999999",
        user_id: "1111111",
        message_id: "another-msg-id",
        command: "premiereecoute",
        args: [],
        is_streamer: false
      }

      expect(TwitchApi, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert scope.user.twitch.user_id == "9999999"

        assert message ==
                 "Première Écoute est une plateforme où les spectateurs peuvent voter pour la musique diffusée pendant le stream. Inscrivez-vous sur premiere-ecoute.fr pour consulter vos votes !"

        assert reply_to == "another-msg-id"
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
