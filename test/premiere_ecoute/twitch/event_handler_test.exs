defmodule PremiereEcoute.Twitch.EventHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.Players.SpotifyProbe
  alias PremiereEcoute.Twitch.EventHandler
  alias PremiereEcoute.Events.Twitch.StreamStarted

  defp stream_started(user), do: %StreamStarted{broadcaster_id: user.twitch.user_id, broadcaster_name: user.username}

  test "enqueues the probe when a streamer with Spotify connected goes live" do
    user = user_fixture(%{twitch: %{}, spotify: %{}})

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:noreply, %{}} = EventHandler.handle_info(stream_started(user), %{})

      assert_enqueued worker: SpotifyProbe, args: %{user_id: user.id}
    end)
  end

  test "does not enqueue the probe when Spotify is not connected" do
    user = user_fixture(%{twitch: %{}})

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:noreply, %{}} = EventHandler.handle_info(stream_started(user), %{})

      refute_enqueued worker: SpotifyProbe
    end)
  end

  test "does not enqueue the probe when the broadcaster is unknown" do
    event = %StreamStarted{broadcaster_id: "unknown_id", broadcaster_name: "unknown"}

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:noreply, %{}} = EventHandler.handle_info(event, %{})

      refute_enqueued worker: SpotifyProbe
    end)
  end
end
