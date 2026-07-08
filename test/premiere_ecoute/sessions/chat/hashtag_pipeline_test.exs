defmodule PremiereEcoute.Sessions.Chat.HashtagPipelineTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.Chat.HashtagMessage
  alias PremiereEcouteCore.Cache

  @pipeline PremiereEcoute.Sessions.Chat.HashtagPipeline

  setup do
    start_supervised(@pipeline)

    Cache.clear(:hashtags)
    on_exit(fn -> Cache.clear(:hashtags) end)

    :ok
  end

  describe "publish/2 - MessageSent" do
    test "caches a message containing a hashtag" do
      PremiereEcouteCore.publish(@pipeline, %MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "#hype this album is fire",
        is_streamer: false
      })

      :timer.sleep(100)

      assert [%{hashtag: "#hype", message: "this album is fire"}] = HashtagMessage.list("1234")
    end

    test "ignores messages without a hashtag" do
      PremiereEcouteCore.publish(@pipeline, %MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "no hashtag here",
        is_streamer: false
      })

      :timer.sleep(100)

      assert HashtagMessage.list("1234") == []
    end

    test "caches messages with no active session (not session-gated)" do
      PremiereEcouteCore.publish(@pipeline, %MessageSent{
        broadcaster_id: "no-session-broadcaster",
        user_id: "viewer1",
        message: "#hype still works",
        is_streamer: false
      })

      :timer.sleep(100)

      assert [%{hashtag: "#hype"}] = HashtagMessage.list("no-session-broadcaster")
    end

    test "caches multiple messages in order" do
      for {message, i} <- Enum.with_index(["#hype first", "#newalbum second"]) do
        PremiereEcouteCore.publish(@pipeline, %MessageSent{
          broadcaster_id: "1234",
          user_id: "viewer#{i}",
          message: message,
          is_streamer: false
        })
      end

      :timer.sleep(100)

      assert [%{message: "first"}, %{message: "second"}] = HashtagMessage.list("1234")
    end
  end
end
