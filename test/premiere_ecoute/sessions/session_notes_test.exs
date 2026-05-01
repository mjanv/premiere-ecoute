defmodule PremiereEcoute.Sessions.SessionNotesTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.SessionNote

  setup do
    user = user_fixture()
    session = session_fixture(%{user_id: user.id, status: :active})
    {:ok, session: session}
  end

  describe "add_note/3" do
    test "returns updated session with note included", %{session: session} do
      assert {:ok, %ListeningSession{session_notes: [%SessionNote{content: "good vibe", track_marker_id: nil}]}} =
               ListeningSession.add_note(session, "good vibe")
    end

    test "creates a note linked to the current track marker", %{session: session} do
      marker = insert_track_marker(session, track_number: 1)
      {:ok, updated} = ListeningSession.add_note(session, "on this track", marker.id)
      assert [note] = updated.session_notes
      assert note.track_marker_id == marker.id
    end

    test "rejects empty content", %{session: session} do
      assert {:error, changeset} = ListeningSession.add_note(session, "")
      assert %{content: [_]} = errors_on(changeset)
    end

    test "rejects content exceeding 1000 characters", %{session: session} do
      long = String.duplicate("a", 1001)
      assert {:error, changeset} = ListeningSession.add_note(session, long)
      assert %{content: [_]} = errors_on(changeset)
    end

    test "accepts content of exactly 1000 characters", %{session: session} do
      content = String.duplicate("a", 1000)
      assert {:ok, %ListeningSession{}} = ListeningSession.add_note(session, content)
    end

    test "accepts multiline content", %{session: session} do
      content = "line one\nline two\nline three"
      {:ok, updated} = ListeningSession.add_note(session, content)
      assert [%SessionNote{content: ^content}] = updated.session_notes
    end

    test "accumulates multiple notes on the session", %{session: session} do
      {:ok, session} = ListeningSession.add_note(session, "first")
      {:ok, session} = ListeningSession.add_note(session, "second")
      assert length(session.session_notes) == 2
    end
  end

  describe "delete_note/2" do
    test "returns updated session with note removed", %{session: session} do
      {:ok, session} = ListeningSession.add_note(session, "to delete")
      [note] = session.session_notes

      assert {:ok, %ListeningSession{session_notes: []}} = ListeningSession.delete_note(session, note)
    end

    test "notes from other sessions are unaffected", %{session: session} do
      other_user = user_fixture()
      other_session = session_fixture(%{user_id: other_user.id, status: :active})

      {:ok, session} = ListeningSession.add_note(session, "mine")
      {:ok, other_session} = ListeningSession.add_note(other_session, "theirs")

      [note] = session.session_notes
      ListeningSession.delete_note(session, note)

      {:ok, loaded} = {:ok, ListeningSession.get(other_session.id)}
      assert [%SessionNote{}] = loaded.session_notes
    end
  end

  describe "current_track_marker_id/1" do
    test "returns nil when session has no track markers", %{session: session} do
      assert nil == ListeningSession.current_track_marker_id(session)
    end

    test "returns nil when track_markers is not loaded" do
      assert nil == ListeningSession.current_track_marker_id(%ListeningSession{track_markers: %Ecto.Association.NotLoaded{}})
    end

    test "returns the id of the most recent track marker", %{session: session} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      earlier = DateTime.add(now, -60, :second)

      marker1 = insert_track_marker(session, track_number: 1, started_at: earlier)
      marker2 = insert_track_marker(session, track_number: 2, started_at: now)

      loaded = ListeningSession.get(session.id)
      assert ListeningSession.current_track_marker_id(loaded) == marker2.id
      assert ListeningSession.current_track_marker_id(loaded) != marker1.id
    end
  end

  describe "session preload includes session_notes" do
    test "get/1 returns session with session_notes preloaded", %{session: session} do
      {:ok, session} = ListeningSession.add_note(session, "first")
      {:ok, session} = ListeningSession.add_note(session, "second")

      assert length(session.session_notes) == 2
      assert Enum.all?(session.session_notes, &match?(%SessionNote{}, &1))
    end

    test "session_notes are deleted when session is deleted", %{session: session} do
      {:ok, updated} = ListeningSession.add_note(session, "will be gone")
      [note] = updated.session_notes
      assert note.listening_session_id == session.id

      PremiereEcoute.Repo.delete(session)

      assert nil == PremiereEcoute.Repo.get(SessionNote, note.id)
    end
  end

  defp insert_track_marker(session, attrs) do
    alias PremiereEcoute.Sessions.ListeningSession.TrackMarker

    defaults = %{
      listening_session_id: session.id,
      track_id: System.unique_integer([:positive]),
      track_number: attrs[:track_number] || 1,
      started_at: attrs[:started_at] || DateTime.utc_now() |> DateTime.truncate(:second)
    }

    {:ok, marker} =
      %TrackMarker{}
      |> TrackMarker.changeset(defaults)
      |> PremiereEcoute.Repo.insert()

    marker
  end
end
