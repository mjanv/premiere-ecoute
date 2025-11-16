defmodule PremiereEcoute.Apis.TwitchQueueTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.RateLimit
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcoute.Apis.TwitchQueue
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    bot = user_fixture(%{twitch: %{user_id: "467189141", access_token: "bot_token"}})
    Cache.put(:users, :bot, bot)

    start_supervised!(RateLimit)
    {:ok, pid} = start_supervised(TwitchQueue)

    :timer.sleep(100)

    {:ok, %{pid: pid, bot: bot}}
  end

  describe "circuit breaker transitions" do
    test "circuit starts in closed state" do
      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :closed
      assert state.messages == []
      assert is_nil(state.timer)
    end

    test "circuit opens when rate limit is hit and queues messages", %{bot: _bot} do
      message = %{user_id: "141981764", message: "test"}

      # Pre-hit the broadcaster rate limit (1 message per second)
      RateLimit.hit("broadcaster:#{message.user_id}", :timer.seconds(1), 1)

      TwitchQueue.push({:do_send_chat_message, message})
      :timer.sleep(100)

      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :open
      assert length(state.messages) == 1
      assert state.messages == [{:do_send_chat_message, message}]
      refute is_nil(state.timer)
    end

    test "circuit stays open and queues additional messages", %{bot: _bot} do
      message1 = %{user_id: "141981764", message: "test1"}
      message2 = %{user_id: "141981764", message: "test2"}

      # Pre-hit the broadcaster rate limit
      RateLimit.hit("broadcaster:#{message1.user_id}", :timer.seconds(1), 1)

      TwitchQueue.push({:do_send_chat_message, message1})
      :timer.sleep(100)

      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :open

      TwitchQueue.push({:do_send_chat_message, message2})
      :timer.sleep(100)

      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :open
      assert length(state.messages) == 2

      assert state.messages == [
               {:do_send_chat_message, message1},
               {:do_send_chat_message, message2}
             ]
    end

    test "circuit closes after retry with successful API call", %{bot: _bot} do
      message = %{user_id: "141981764", message: "test"}

      ApiMock.stub(
        TwitchApi,
        path: {:post, "/helix/chat/messages"},
        status: 200,
        response: %{"data" => [%{"message_id" => "abc-123-def", "is_sent" => true}]}
      )

      # Pre-hit the broadcaster rate limit
      RateLimit.hit("broadcaster:#{message.user_id}", :timer.seconds(1), 1)

      TwitchQueue.push({:do_send_chat_message, message})
      :timer.sleep(100)

      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :open

      # Wait for the rate limit window to expire
      :timer.sleep(1100)

      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :closed
      assert state.messages == []
    end

    test "circuit closes immediately when retry is triggered with empty queue" do
      send(TwitchQueue, :retry)
      :timer.sleep(100)

      state = :sys.get_state(TwitchQueue)
      assert state.circuit == :closed
      assert state.messages == []
    end
  end
end
