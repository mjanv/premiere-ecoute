defmodule PremiereEcoute.Accounts.Workers.SubscribeStreamEventsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Workers.SubscribeStreamEvents
  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    Cache.put(:tokens, :twitch, "token")
    :ok
  end

  describe "subscribe_streamer/1" do
    test "subscribes a streamer to stream events" do
      streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: %{"data" => [], "total" => 0, "total_cost" => 0, "max_total_cost" => 10_000, "pagination" => %{}},
        params: %{"user_id" => "1234"},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      assert :ok = SubscribeStreamEvents.subscribe_streamer(streamer)
    end

    test "returns error for streamers without Twitch OAuth tokens" do
      streamer = user_fixture(%{role: :streamer})

      assert :ok = SubscribeStreamEvents.subscribe_streamer(streamer)
    end

    test "returns error for API failures" do
      streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: %{"data" => [], "total" => 0, "total_cost" => 0, "max_total_cost" => 10_000, "pagination" => %{}},
        params: %{"user_id" => "1234"},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        response: %{
          "error" => "Internal Server Error",
          "message" => "service unavailable",
          "status" => 500
        },
        status: 500
      )

      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        response: %{
          "error" => "Internal Server Error",
          "message" => "service unavailable",
          "status" => 500
        },
        status: 500
      )

      assert :error = SubscribeStreamEvents.subscribe_streamer(streamer)
    end
  end
end
