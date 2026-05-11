defmodule PremiereEcoute.Collections.EventHandlerTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Collections.EventHandler
  alias PremiereEcoute.Events.Twitch.RewardRedeemed
  alias PremiereEcoute.Twitch.Redemption
  alias PremiereEcouteCore.Cache

  setup do
    start_supervised!(EventHandler)
    :ok
  end

  describe "handle_info/2 - RewardRedeemed" do
    test "appends redemption to cache and broadcasts to collection topic" do
      broadcaster_id = "1337"
      session_id = 42

      Cache.put(:collections, broadcaster_id, %{session_id: session_id, tracks: [], rewards: [], redemptions: []})
      PremiereEcoute.PubSub.subscribe("collection:#{session_id}")

      event = %RewardRedeemed{
        id: "redemption-1",
        broadcaster_id: broadcaster_id,
        user_id: "9001",
        user_login: "viewer_user",
        reward_id: "reward-abc",
        reward_title: "Song request",
        user_input: "Some song",
        status: "unfulfilled",
        redeemed_at: "2024-01-01T00:00:00Z"
      }

      send(EventHandler, event)

      assert_receive {:redemption_received, %Redemption{} = redemption}, 500
      assert redemption.id == "redemption-1"
      assert redemption.user_login == "viewer_user"
      assert redemption.reward_title == "Song request"
      assert redemption.user_input == "Some song"
      assert redemption.status == :unfulfilled

      {:ok, cached} = Cache.get(:collections, broadcaster_id)
      assert length(cached.redemptions) == 1
      assert hd(cached.redemptions).id == "redemption-1"
    end

    test "accumulates multiple redemptions in order" do
      broadcaster_id = "1337"
      session_id = 43

      Cache.put(:collections, broadcaster_id, %{session_id: session_id, tracks: [], rewards: [], redemptions: []})
      PremiereEcoute.PubSub.subscribe("collection:#{session_id}")

      for i <- 1..3 do
        send(EventHandler, %RewardRedeemed{
          id: "redemption-#{i}",
          broadcaster_id: broadcaster_id,
          user_id: "user-#{i}",
          user_login: "viewer_#{i}",
          reward_id: "reward-abc",
          reward_title: "Song request",
          user_input: "",
          status: "unfulfilled",
          redeemed_at: "2024-01-01T00:00:0#{i}Z"
        })

        assert_receive {:redemption_received, _}, 500
      end

      {:ok, cached} = Cache.get(:collections, broadcaster_id)
      assert length(cached.redemptions) == 3
      assert Enum.map(cached.redemptions, & &1.id) == ["redemption-1", "redemption-2", "redemption-3"]
    end

    test "drops redemption when no active session for broadcaster" do
      broadcaster_id = "unknown-broadcaster"

      event = %RewardRedeemed{
        id: "redemption-x",
        broadcaster_id: broadcaster_id,
        user_id: "9001",
        user_login: "viewer_user",
        reward_id: "reward-abc",
        reward_title: "Song request",
        user_input: "",
        status: "unfulfilled",
        redeemed_at: "2024-01-01T00:00:00Z"
      }

      send(EventHandler, event)

      # give the handler time to process
      Process.sleep(50)

      assert {:ok, nil} = Cache.get(:collections, broadcaster_id)
    end

    test "ignores unrelated messages" do
      send(EventHandler, :some_unrelated_message)
      send(EventHandler, {:unknown, :event})
      # handler stays alive and responds to a subsequent valid event
      broadcaster_id = "5555"
      session_id = 99

      Cache.put(:collections, broadcaster_id, %{session_id: session_id, tracks: [], rewards: [], redemptions: []})
      PremiereEcoute.PubSub.subscribe("collection:#{session_id}")

      send(EventHandler, %RewardRedeemed{
        id: "after-noise",
        broadcaster_id: broadcaster_id,
        user_id: "u1",
        user_login: "viewer",
        reward_id: "r1",
        reward_title: "Skip",
        user_input: nil,
        status: "unfulfilled",
        redeemed_at: "2024-01-01T00:00:00Z"
      })

      assert_receive {:redemption_received, %Redemption{id: "after-noise"}}, 500
    end
  end
end
