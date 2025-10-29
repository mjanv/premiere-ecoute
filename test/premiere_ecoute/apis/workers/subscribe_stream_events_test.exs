defmodule PremiereEcoute.Apis.Workers.SubscribeStreamEventsTest do
  use PremiereEcoute.DataCase
  use Oban.Testing, repo: PremiereEcoute.Repo

  alias PremiereEcoute.Apis.Workers.SubscribeStreamEvents
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcoute.ApiMock
  alias PremiereEcouteCore.Cache

  setup do
    Cache.put(:tokens, :twitch, "token")
    :ok
  end

  describe "perform/1" do
    test "subscribes all streamers to stream events" do
      # Create two streamers and one viewer
      streamer1 = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})
      streamer2 = user_fixture(%{role: :streamer, twitch: %{user_id: "5678", username: "streamer2"}})
      _viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "9999", username: "viewer"}})

      # Mock API calls for streamer1
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

      # Mock API calls for streamer2
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

      assert :ok = perform_job(SubscribeStreamEvents, %{})
    end

    test "handles streamers without Twitch OAuth tokens" do
      # Create a streamer without Twitch connection
      _streamer = user_fixture(%{role: :streamer})

      # Should succeed even though no subscriptions were created
      assert :ok = perform_job(SubscribeStreamEvents, %{})
    end

    test "handles API failures gracefully" do
      # Create a streamer
      _streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

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

      # Should still return :ok even with failures
      assert :ok = perform_job(SubscribeStreamEvents, %{})
    end

    test "only processes users with streamer role" do
      # Create users with different roles
      _admin = user_fixture(%{role: :admin, twitch: %{user_id: "1111", username: "admin"}})
      _viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "2222", username: "viewer"}})
      _bot = user_fixture(%{role: :bot, twitch: %{user_id: "3333", username: "bot"}})

      # No API calls should be made since there are no streamers
      assert :ok = perform_job(SubscribeStreamEvents, %{})
    end
  end
end
