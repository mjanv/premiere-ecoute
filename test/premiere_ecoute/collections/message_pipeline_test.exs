defmodule PremiereEcoute.Collections.CollectionSession.MessagePipelineTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Collections.CollectionSession.MessagePipeline
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcouteCore.Cache

  @pipeline MessagePipeline

  setup do
    start_supervised(@pipeline)

    user = user_fixture(%{twitch: %{user_id: "broadcaster1"}})
    session = collection_session_fixture(user)

    Cache.put(:collections, "broadcaster1", %{
      session_id: session.id,
      active_track_id: "track1",
      votes_a: 0,
      votes_b: 0
    })

    {:ok, %{user: user, session: session}}
  end

  describe "process/1" do
    test "parses '1' as side :a" do
      msg = %MessageSent{broadcaster_id: "broadcaster1", user_id: "viewer1", message: "1"}
      assert {:ok, %{side: :a}} = MessagePipeline.process(msg)
    end

    test "parses '2' as side :b" do
      msg = %MessageSent{broadcaster_id: "broadcaster1", user_id: "viewer1", message: "2"}
      assert {:ok, %{side: :b}} = MessagePipeline.process(msg)
    end

    test "parses messages ending with ' 1' as side :a" do
      msg = %MessageSent{broadcaster_id: "broadcaster1", user_id: "viewer1", message: "vote 1"}
      assert {:ok, %{side: :a}} = MessagePipeline.process(msg)
    end

    test "parses messages ending with ' 2' as side :b" do
      msg = %MessageSent{broadcaster_id: "broadcaster1", user_id: "viewer1", message: "vote 2"}
      assert {:ok, %{side: :b}} = MessagePipeline.process(msg)
    end

    test "rejects non-vote messages" do
      msg = %MessageSent{broadcaster_id: "broadcaster1", user_id: "viewer1", message: "hello"}
      assert {:error, :not_a_collection_vote} = MessagePipeline.process(msg)
    end

    test "rejects messages when no active vote window" do
      Cache.put(:collections, "broadcaster1", %{session_id: 999, active_track_id: nil})
      msg = %MessageSent{broadcaster_id: "broadcaster1", user_id: "viewer1", message: "1"}
      assert {:error, :not_a_collection_vote} = MessagePipeline.process(msg)
    end

    test "rejects messages when broadcaster not in cache" do
      msg = %MessageSent{broadcaster_id: "unknown", user_id: "viewer1", message: "1"}
      assert {:error, :not_a_collection_vote} = MessagePipeline.process(msg)
    end
  end

  describe "publish/2 - vote tallying" do
    test "accumulates votes_a and votes_b in cache" do
      messages = [
        %MessageSent{broadcaster_id: "broadcaster1", user_id: "v1", message: "1"},
        %MessageSent{broadcaster_id: "broadcaster1", user_id: "v2", message: "2"},
        %MessageSent{broadcaster_id: "broadcaster1", user_id: "v3", message: "1"}
      ]

      for msg <- messages do
        PremiereEcouteCore.publish(@pipeline, msg)
      end

      :timer.sleep(600)

      {:ok, cached} = Cache.get(:collections, "broadcaster1")
      assert cached.votes_a == 2
      assert cached.votes_b == 1
    end

    test "broadcasts vote_update after each batch", %{session: session} do
      PremiereEcoute.PubSub.subscribe("collection:#{session.id}")

      PremiereEcouteCore.publish(@pipeline, %MessageSent{
        broadcaster_id: "broadcaster1",
        user_id: "v1",
        message: "1"
      })

      :timer.sleep(600)

      assert_receive {:vote_update, %{votes_a: 1, votes_b: 0}}
    end
  end
end
