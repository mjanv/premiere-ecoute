defmodule PremiereEcoute.Collections.CollectionSessionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Events.CollectionCreated
  alias PremiereEcoute.Events.CollectionDeleted
  alias PremiereEcoute.Events.Store

  describe "changeset/2" do
    test "valid session with required fields" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      attrs = %{
        user_id: user.id,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      assert %{valid?: true} = CollectionSession.changeset(%CollectionSession{}, attrs)
    end

    test "invalid without required associations" do
      changeset = CollectionSession.changeset(%CollectionSession{}, %{})
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).origin_playlist_id
      assert "can't be blank" in errors_on(changeset).destination_playlist_id
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

  describe "create/1" do
    test "appends CollectionCreated event" do
      user = user_fixture()
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      {:ok, session} =
        CollectionSession.create(%{
          user_id: user.id,
          origin_playlist_id: origin.id,
          destination_playlist_id: destination.id
        })

      assert Store.last("collection-#{session.id}") == %CollectionCreated{id: session.id}
    end
  end

  describe "delete/1" do
    test "deletes the session" do
      user = user_fixture()
      session = collection_session_fixture(user)

      assert {:ok, _} = CollectionSession.delete(session)
      assert is_nil(CollectionSession.get(session.id))
    end

    test "appends CollectionDeleted event" do
      user = user_fixture()
      session = collection_session_fixture(user)

      {:ok, _} = CollectionSession.delete(session)

      session_id = session.id
      assert %CollectionDeleted{id: ^session_id} = Store.last("collection-#{session_id}")
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
