defmodule PremiereEcoute.Collections.CollectionDecisionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Collections.CollectionDecision

  describe "decide/2" do
    test "creates a kept decision" do
      user = user_fixture()
      session = collection_session_fixture(user)

      attrs = %{
        track_id: "track_1",
        track_name: "Song A",
        artist: "Artist",
        position: 0,
        decision: :kept,
        votes_a: 0,
        votes_b: 0,
        duel_track_id: nil
      }

      assert {:ok, decision} = CollectionDecision.decide(session.id, attrs)
      assert decision.decision == :kept
      assert decision.track_id == "track_1"
    end

    test "creates a rejected decision" do
      user = user_fixture()
      session = collection_session_fixture(user)

      attrs = %{
        track_id: "track_2",
        track_name: "Song B",
        artist: "Artist",
        position: 1,
        decision: :rejected,
        votes_a: 0,
        votes_b: 0,
        duel_track_id: nil
      }

      assert {:ok, decision} = CollectionDecision.decide(session.id, attrs)
      assert decision.decision == :rejected
    end

    test "silently ignores duplicate track in same session" do
      user = user_fixture()
      session = collection_session_fixture(user)

      attrs = %{
        track_id: "track_1",
        track_name: "Song A",
        artist: "Artist",
        position: 0,
        decision: :kept,
        votes_a: 0,
        votes_b: 0,
        duel_track_id: nil
      }

      {:ok, first} = CollectionDecision.decide(session.id, attrs)
      assert {:ok, second} = CollectionDecision.decide(session.id, attrs)
      # on_conflict: :nothing returns id: nil for the skipped row
      assert is_nil(second.id)
      # first decision is unchanged
      assert first.decision == :kept
      assert length(CollectionDecision.all_for_session(session.id)) == 1
    end
  end

  describe "kept_for_session/1" do
    test "returns only kept decisions ordered by position" do
      user = user_fixture()
      session = collection_session_fixture(user)

      collection_decision_fixture(session.id, %{track_id: "a", position: 0, decision: :kept})
      collection_decision_fixture(session.id, %{track_id: "b", position: 1, decision: :rejected})
      collection_decision_fixture(session.id, %{track_id: "c", position: 2, decision: :kept})

      kept = CollectionDecision.kept_for_session(session.id)

      assert length(kept) == 2
      assert Enum.map(kept, & &1.track_id) == ["a", "c"]
    end

    test "returns empty list when no kept decisions" do
      user = user_fixture()
      session = collection_session_fixture(user)

      collection_decision_fixture(session.id, %{track_id: "a", position: 0, decision: :rejected})

      assert CollectionDecision.kept_for_session(session.id) == []
    end
  end

  describe "rejected_for_session/1" do
    test "returns only rejected decisions ordered by position" do
      user = user_fixture()
      session = collection_session_fixture(user)

      collection_decision_fixture(session.id, %{track_id: "a", position: 0, decision: :kept})
      collection_decision_fixture(session.id, %{track_id: "b", position: 1, decision: :rejected})
      collection_decision_fixture(session.id, %{track_id: "c", position: 2, decision: :rejected})

      rejected = CollectionDecision.rejected_for_session(session.id)

      assert length(rejected) == 2
      assert Enum.map(rejected, & &1.track_id) == ["b", "c"]
    end

    test "returns empty list when no rejected decisions" do
      user = user_fixture()
      session = collection_session_fixture(user)

      collection_decision_fixture(session.id, %{track_id: "a", position: 0, decision: :kept})

      assert CollectionDecision.rejected_for_session(session.id) == []
    end

    test "does not include skipped decisions" do
      user = user_fixture()
      session = collection_session_fixture(user)

      collection_decision_fixture(session.id, %{track_id: "a", position: 0, decision: :skipped})
      collection_decision_fixture(session.id, %{track_id: "b", position: 1, decision: :rejected})

      rejected = CollectionDecision.rejected_for_session(session.id)

      assert length(rejected) == 1
      assert hd(rejected).track_id == "b"
    end
  end
end
