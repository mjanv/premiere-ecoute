defmodule PremiereEcouteWeb.Webhooks.TwitchControllerTest do
  use PremiereEcouteWeb.ConnCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Commands.Chat.SendChatCommand
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Events.Chat.PollEnded
  alias PremiereEcoute.Events.Chat.PollStarted
  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcoute.Events.Twitch.StreamEnded
  alias PremiereEcoute.Events.Twitch.StreamStarted
  alias PremiereEcouteWeb.Plugs.TwitchHmacValidator
  alias PremiereEcouteWeb.Webhooks.TwitchController

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    start_supervised(PremiereEcoute.Sessions.Scores.MessagePipeline)

    :ok
  end

  describe "POST /webhooks/twitch" do
    test "handles !premiereecoute command with English language", %{conn: conn} do
      _broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "broadcaster_token"},
          profile: %{language: :en}
        })

      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_premiereecoute_command.json")

      expect(PremiereEcoute.Apis.Streaming.TwitchApi.Mock, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.twitch.user_id == "1971641"
        assert scope.user.profile.language == :en

        assert message ==
                 "Premiere Ecoute is a platform where viewers can vote on music played during the stream. Register on premiere-ecoute.fr to view your votes!"

        assert reply_to == "premiereecoute-msg-123"
        :ok
      end)

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "notification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "handles !premiereecoute command with French language", %{conn: conn} do
      _broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "broadcaster_token"},
          profile: %{language: :fr}
        })

      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_premiereecoute_command.json")

      expect(PremiereEcoute.Apis.Streaming.TwitchApi.Mock, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.twitch.user_id == "1971641"
        assert scope.user.profile.language == :fr

        assert message ==
                 "Première Écoute est une plateforme où les spectateurs peuvent voter pour la musique diffusée pendant le stream. Inscrivez-vous sur premiere-ecoute.fr pour consulter vos votes !"

        assert reply_to == "premiereecoute-msg-123"
        :ok
      end)

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "notification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "handles !premiereecoute command with Italian language", %{conn: conn} do
      _broadcaster =
        user_fixture(%{
          twitch: %{user_id: "1971641", access_token: "broadcaster_token"},
          profile: %{language: :it}
        })

      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_premiereecoute_command.json")

      expect(PremiereEcoute.Apis.Streaming.TwitchApi.Mock, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.twitch.user_id == "1971641"
        assert scope.user.profile.language == :it

        assert message ==
                 "Premiere Ecoute è una piattaforma dove gli spettatori possono votare la musica suonata durante lo stream. Registrati su premiere-ecoute.fr per visualizzare i tuoi voti!"

        assert reply_to == "premiereecoute-msg-123"
        :ok
      end)

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "notification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "handles !vote command with active session", %{conn: conn} do
      broadcaster = user_fixture(%{twitch: %{user_id: "1971641", access_token: "broadcaster_token"}})
      viewer_id = "4145994"

      # Create active session and votes
      session = session_fixture(%{user_id: broadcaster.id, status: :active})
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 1, value: "8"})
      vote_fixture(%{viewer_id: viewer_id, session_id: session.id, track_id: 2, value: "10"})

      payload = %{
        "subscription" => %{
          "id" => "test-sub-id",
          "type" => "channel.chat.message",
          "version" => "1",
          "condition" => %{"broadcaster_user_id" => "1971641", "user_id" => "bot_id"},
          "created_at" => "2023-11-06T18:11:47.492253549Z"
        },
        "event" => %{
          "broadcaster_user_id" => "1971641",
          "broadcaster_user_login" => "streamer",
          "broadcaster_user_name" => "streamer",
          "chatter_user_id" => viewer_id,
          "chatter_user_login" => "viewer32",
          "chatter_user_name" => "viewer32",
          "message_id" => "vote-msg-123",
          "message" => %{"text" => "!vote", "fragments" => [%{"type" => "text", "text" => "!vote"}]},
          "message_type" => "text"
        }
      }

      expect(PremiereEcoute.Apis.Streaming.TwitchApi.Mock, :send_reply_message, fn scope, message, reply_to ->
        assert scope.user.id == broadcaster.id
        assert message == "9.0/10"
        assert reply_to == "vote-msg-123"
        :ok
      end)

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "notification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "handles webhook verification challenge", %{conn: conn} do
      payload = %{
        "challenge" => "pogchamp-kappa-360noscope-vohiyo",
        "subscription" => %{
          "id" => "f1c2a387-161a-49f9-a165-0f21d7a4e1c4",
          "status" => "webhook_callback_verification_pending",
          "type" => "channel.follow",
          "version" => "1",
          "cost" => 1,
          "condition" => %{
            "broadcaster_user_id" => "12826"
          },
          "transport" => %{
            "method" => "webhook",
            "callback" => "https://example.com/webhooks/callback"
          },
          "created_at" => "2019-11-16T10:11:12.634234626Z"
        }
      }

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "webhook_callback_verification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 200
      assert response.resp_body == "pogchamp-kappa-360noscope-vohiyo"
      assert get_resp_header(response, "content-type") == ["text/plain; charset=utf-8"]
    end

    test "handles subscription revocation", %{conn: conn} do
      payload = %{
        "subscription" => %{
          "id" => "f1c2a387-161a-49f9-a165-0f21d7a4e1c4",
          "status" => "authorization_revoked",
          "type" => "channel.follow",
          "cost" => 1,
          "version" => "1",
          "condition" => %{
            "broadcaster_user_id" => "12826"
          },
          "transport" => %{
            "method" => "webhook",
            "callback" => "https://example.com/webhooks/callback"
          },
          "created_at" => "2019-11-16T10:11:12.634234626Z"
        }
      }

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "revocation")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 204
      assert response.resp_body == ""
    end

    test "handles channel.chat.message notification", %{conn: conn} do
      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_message.json")

      response =
        conn
        |> sign_conn(payload)
        |> put_req_header("twitch-eventsub-message-type", "notification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "revokes message with wrong HMAC signature", %{conn: conn} do
      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_message.json")

      response =
        conn
        |> sign_conn(payload, "wrong")
        |> put_req_header("twitch-eventsub-message-type", "notification")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twitch", Jason.encode!(payload))

      assert response.status == 401
      assert response.resp_body == ""
    end

    defp sign_conn(conn, payload, signature \\ nil) do
      id = UUID.uuid4()
      timestamp = DateTime.to_iso8601(DateTime.utc_now(), :extended)
      hmac = TwitchHmacValidator.signature("s3cre77890ab", id <> timestamp <> Jason.encode!(payload))

      conn
      |> put_req_header("twitch-eventsub-message-id", id)
      |> put_req_header("twitch-eventsub-message-timestamp", timestamp)
      |> put_req_header("twitch-eventsub-message-signature", signature || hmac)
    end
  end

  describe "handle/1" do
    test "channel.chat.message - message" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_message.json")

      event = TwitchController.handle(payload)

      assert event == %MessageSent{
               broadcaster_id: "1971641",
               user_id: "4145994",
               message: "Hi chat",
               is_streamer: false
             }
    end

    test "channel.chat.message - command" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_command.json")

      event = TwitchController.handle(payload)

      assert event == %SendChatCommand{
               broadcaster_id: "1971641",
               user_id: "4145994",
               message_id: "cc106a89-1814-919d-454c-f4f2f970aae7",
               command: "command",
               args: ["arg1", "arg2"],
               is_streamer: false
             }
    end

    test "channel.chat.message - !premiereecoute command" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_premiereecoute_command.json")

      event = TwitchController.handle(payload)

      assert event == %SendChatCommand{
               broadcaster_id: "1971641",
               user_id: "4145994",
               message_id: "premiereecoute-msg-123",
               command: "premiereecoute",
               args: [],
               is_streamer: false
             }
    end

    test "channel.poll.begin" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_poll_begin.json")

      event = TwitchController.handle(payload)

      assert event == %PollStarted{
               id: "1243456",
               title: "Aren't shoes just really hard socks?",
               votes: %{"Yeah!" => 0, "No!" => 0, "Maybe!" => 0}
             }
    end

    test "channel.poll.progress" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_poll_progress.json")

      event = TwitchController.handle(payload)

      assert event == %PollUpdated{
               id: "1243456",
               votes: %{"Yeah!" => 12, "No!" => 14, "Maybe!" => 7}
             }
    end

    test "channel.poll.end" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_poll_end.json")

      event = TwitchController.handle(payload)

      assert event == %PollEnded{
               id: "1243456",
               votes: %{"Blue" => 120, "Yellow" => 140, "Green" => 80}
             }
    end

    test "stream.online" do
      payload = ApiMock.payload("twitch_api/eventsub/stream_online.json")

      event = TwitchController.handle(payload)

      assert event == %StreamStarted{
               broadcaster_id: "1337",
               broadcaster_name: "Cool_User",
               started_at: "2020-10-11T10:11:12.123Z"
             }
    end

    test "stream.offline" do
      payload = ApiMock.payload("twitch_api/eventsub/stream_offline.json")

      event = TwitchController.handle(payload)

      assert event == %StreamEnded{
               broadcaster_id: "1337",
               broadcaster_name: "Cool_User"
             }
    end
  end
end
