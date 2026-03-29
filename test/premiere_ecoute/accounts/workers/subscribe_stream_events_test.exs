defmodule PremiereEcoute.Accounts.Workers.SubscribeStreamEventsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Workers.SubscribeStreamEvents
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  describe "subscribe_streamer/1" do
    test "subscribes a streamer to stream events" do
      streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

      expect(TwitchApi, :get_event_subscriptions, fn _scope -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn _scope, "stream.online" -> {:ok, %{}} end)
      expect(TwitchApi, :subscribe, fn _scope, "stream.offline" -> {:ok, %{}} end)

      assert :ok = SubscribeStreamEvents.subscribe_streamer(streamer)
    end

    test "returns error for streamers without Twitch OAuth tokens" do
      streamer = user_fixture(%{role: :streamer})

      assert :ok = SubscribeStreamEvents.subscribe_streamer(streamer)
    end

    test "returns error for API failures" do
      streamer = user_fixture(%{role: :streamer, twitch: %{user_id: "1234", username: "streamer1"}})

      expect(TwitchApi, :get_event_subscriptions, fn _scope -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn _scope, "stream.online" -> {:error, :service_unavailable} end)
      expect(TwitchApi, :subscribe, fn _scope, "stream.offline" -> {:error, :service_unavailable} end)

      assert :error = SubscribeStreamEvents.subscribe_streamer(streamer)
    end
  end
end
