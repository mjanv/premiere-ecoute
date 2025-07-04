defmodule PremiereEcoute.Apis.TwitchClientTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.TwitchClient

  @state %{}

  describe "handle/2" do
    test "session_welcome" do
      payload = %{
        "metadata" => %{
          "message_id" => "c29a49a8-c9e4-4829-b580-a0bcd55c8852",
          "message_timestamp" => "2025-07-03T20:54:19.968504363Z",
          "message_type" => "session_welcome"
        },
        "payload" => %{
          "session" => %{
            "connected_at" => "2025-07-03T20:54:19.964722936Z",
            "id" => "AgoQjtkaqSWwQCm8AON9IAbtcxIGY2VsbC1j",
            "keepalive_timeout_seconds" => 10,
            "reconnect_url" => nil,
            "recovery_url" => nil,
            "status" => "connected"
          }
        }
      }

      assert {:ok, @state} = TwitchClient.handle(@state, payload)
    end

    test "session_keepalive" do
      payload = %{
        "metadata" => %{
          "message_id" => "bc01bf43-56e3-41d5-bd48-4665624f53af",
          "message_timestamp" => "2025-07-03T20:54:29.96885754Z",
          "message_type" => "session_keepalive"
        },
        "payload" => %{}
      }

      assert {:ok, @state} = TwitchClient.handle(@state, payload)
    end

    test "session_reconnect" do
      payload = %{
        "metadata" => %{
          "message_id" => "84c1e79a-2a4b-4c13-ba0b-4312293e9308",
          "message_type" => "session_reconnect",
          "message_timestamp" => "2022-11-18T09:10:11.634234626Z"
        },
        "payload" => %{
          "session" => %{
            "id" => "AQoQexAWVYKSTIu4ec_2VAxyuhAB",
            "status" => "reconnecting",
            "keepalive_timeout_seconds" => nil,
            "reconnect_url" => "wss://eventsub.wss.twitch.tv?...",
            "connected_at" => "2022-11-16T10:11:12.634234626Z"
          }
        }
      }

      assert {:ok, @state} = TwitchClient.handle(@state, payload)
    end
  end
end
