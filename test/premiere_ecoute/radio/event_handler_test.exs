defmodule PremiereEcoute.Radio.EventHandlerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.Twitch.StreamEnded
  alias PremiereEcoute.Events.Twitch.StreamStarted
  alias PremiereEcoute.Radio.EventHandler
  alias PremiereEcoute.Radio.Workers.TrackSpotifyPlayback

  describe "handle_info/2 - StreamStarted" do
    test "enqueues TrackSpotifyPlayback when radio tracking is enabled" do
      user = user_fixture(%{twitch: %{}})
      {:ok, user} = User.edit_user_profile(user, %{radio_settings: %{enabled: true}})
      user = User.get_user_by_twitch_id(user.twitch.user_id)

      event = %StreamStarted{broadcaster_id: user.twitch.user_id, broadcaster_name: user.username}

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:noreply, %{}} = EventHandler.handle_info({:stream_event, event}, %{})

        assert_enqueued worker: TrackSpotifyPlayback, args: %{user_id: user.id}
      end)
    end

    test "does not enqueue job when radio tracking is disabled" do
      user = user_fixture(%{twitch: %{}})
      user = User.get_user_by_twitch_id(user.twitch.user_id)

      event = %StreamStarted{broadcaster_id: user.twitch.user_id, broadcaster_name: user.username}

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:noreply, %{}} = EventHandler.handle_info({:stream_event, event}, %{})

        refute_enqueued worker: TrackSpotifyPlayback
      end)
    end

    test "does not enqueue job when broadcaster is unknown" do
      event = %StreamStarted{broadcaster_id: "unknown_id", broadcaster_name: "unknown"}

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:noreply, %{}} = EventHandler.handle_info({:stream_event, event}, %{})

        refute_enqueued worker: TrackSpotifyPlayback
      end)
    end
  end

  describe "handle_info/2 - StreamEnded" do
    test "is a no-op" do
      event = %StreamEnded{broadcaster_id: "1337", broadcaster_name: "cool_user"}

      assert {:noreply, %{}} = EventHandler.handle_info({:stream_event, event}, %{})
    end
  end
end
