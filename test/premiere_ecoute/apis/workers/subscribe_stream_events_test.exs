defmodule PremiereEcoute.Apis.Workers.SubscribeStreamEventsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcoute.Apis.Workers.SubscribeStreamEvents
  alias PremiereEcouteCore.Cache

  setup do
    Cache.put(:tokens, :twitch, "token")
    :ok
  end

  describe "subscribe_streamer/1" do
    test "subscribes a streamer to stream events" do
      # Create a streamer
      streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

      # Mock API calls for stream.online
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

      # Mock API calls for stream.offline
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

      assert {:ok, user_id} = SubscribeStreamEvents.subscribe_streamer(streamer)
      assert user_id == streamer.id
    end

    test "returns error for streamers without Twitch OAuth tokens" do
      # Create a streamer without Twitch connection
      streamer = user_fixture(%{role: :streamer})

      # Should return error with appropriate message
      assert {:error, {:no_twitch_token, user_id}} = SubscribeStreamEvents.subscribe_streamer(streamer)
      assert user_id == streamer.id
    end

    test "returns error for API failures" do
      # Create a streamer
      streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

      # Mock API failure for stream.online
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

      # Should return error tuple with user id and reason
      assert {:error, {user_id, _reason}} = SubscribeStreamEvents.subscribe_streamer(streamer)
      assert user_id == streamer.id
    end
  end
end
