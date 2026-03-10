defmodule PremiereEcoute.Collections.CollectionSessionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Collections.CollectionSession

  describe "changeset/2" do
    test "valid streamer_choice session requires no vote_duration" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      attrs = %{
        rule: :ordered,
        selection_mode: :streamer_choice,
        user_id: user.id,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      assert %{valid?: true} = CollectionSession.changeset(%CollectionSession{}, attrs)
    end

    test "viewer_vote session requires vote_duration" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      attrs = %{
        rule: :ordered,
        selection_mode: :viewer_vote,
        user_id: user.id,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      changeset = CollectionSession.changeset(%CollectionSession{}, attrs)
      assert "can't be blank" in errors_on(changeset).vote_duration
    end

    test "duel session requires vote_duration" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      attrs = %{
        rule: :ordered,
        selection_mode: :duel,
        user_id: user.id,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      changeset = CollectionSession.changeset(%CollectionSession{}, attrs)
      assert "can't be blank" in errors_on(changeset).vote_duration
    end

    test "viewer_vote with vote_duration is valid" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      attrs = %{
        rule: :ordered,
        selection_mode: :viewer_vote,
        vote_duration: 30,
        user_id: user.id,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      assert %{valid?: true} = CollectionSession.changeset(%CollectionSession{}, attrs)
    end

    test "random rule is accepted" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      attrs = %{
        rule: :random,
        selection_mode: :streamer_choice,
        user_id: user.id,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      assert %{valid?: true} = CollectionSession.changeset(%CollectionSession{}, attrs)
    end
  end

  describe "start/1" do
    test "transitions pending session to active" do
      user = user_fixture()
      session = collection_session_fixture(user)

      assert session.status == :pending
      {:ok, started} = CollectionSession.start(session)
      assert started.status == :active
    end
  end

  describe "complete/1" do
    test "transitions active session to completed" do
      user = user_fixture()
      session = collection_session_fixture(user)
      {:ok, session} = CollectionSession.start(session)

      {:ok, completed} = CollectionSession.complete(session)
      assert completed.status == :completed
    end
  end

  describe "advance/2" do
    test "increments current_index by default step of 1" do
      user = user_fixture()
      session = collection_session_fixture(user)

      assert session.current_index == 0
      {:ok, advanced} = CollectionSession.advance(session)
      assert advanced.current_index == 1
    end

    test "increments current_index by step 2 for duel" do
      user = user_fixture()
      session = collection_session_fixture(user)

      {:ok, advanced} = CollectionSession.advance(session, 2)
      assert advanced.current_index == 2
    end
  end

  describe "all_for_user/1" do
    test "returns sessions for user ordered by most recent" do
      user = user_fixture()
      _s1 = collection_session_fixture(user)
      _s2 = collection_session_fixture(user)

      sessions = CollectionSession.all_for_user(user)
      assert length(sessions) == 2
    end

    test "does not return sessions from other users" do
      user = user_fixture()
      other = user_fixture()

      _session = collection_session_fixture(other)

      assert CollectionSession.all_for_user(user) == []
    end
  end
end
