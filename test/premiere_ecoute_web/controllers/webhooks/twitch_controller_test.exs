defmodule PremiereEcouteWeb.Webhooks.TwitchControllerTest do
  use PremiereEcouteWeb.ConnCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Events.Chat.PollEnded
  alias PremiereEcoute.Events.Chat.PollStarted
  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcouteWeb.Plugs.TwitchHmacValidator
  alias PremiereEcouteWeb.Webhooks.TwitchController

  describe "POST /webhooks/twitch" do
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

    @tag :skip
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
    test "channel.chat.message" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_chat_message.json")

      event = TwitchController.handle(payload)

      assert event == %MessageSent{
               broadcaster_id: "1971641",
               user_id: "4145994",
               message: "Hi chat",
               is_streamer: false
             }
    end

    test "channel.poll.begin" do
      payload = ApiMock.payload("twitch_api/eventsub/channel_poll_begin.json")

      event = TwitchController.handle(payload)

      assert event == %PollStarted{
               id: "1243456",
               title: "Aren’t shoes just really hard socks?",
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
  end
end
