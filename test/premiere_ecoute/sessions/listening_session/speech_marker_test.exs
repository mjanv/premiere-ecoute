defmodule PremiereEcoute.Sessions.ListeningSession.SpeechMarkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.SpeechMarker

  describe "changeset/2" do
    test "valid with required fields" do
      attrs = %{
        listening_session_id: 1,
        started_at: ~U[2026-03-24 10:00:00Z],
        start_ms: 5000,
        end_ms: 8000
      }

      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert changeset.valid?
    end

    test "valid with optional text field" do
      attrs = %{
        listening_session_id: 1,
        started_at: ~U[2026-03-24 10:00:00Z],
        start_ms: 5000,
        end_ms: 8000,
        text: "hello world"
      }

      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert changeset.valid?
    end

    test "invalid when started_at is missing" do
      attrs = %{listening_session_id: 1, start_ms: 0, end_ms: 3000}
      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert "can't be blank" in errors_on(changeset).started_at
    end

    test "invalid when start_ms is missing" do
      attrs = %{listening_session_id: 1, started_at: ~U[2026-03-24 10:00:00Z], end_ms: 3000}
      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert "can't be blank" in errors_on(changeset).start_ms
    end

    test "invalid when end_ms is missing" do
      attrs = %{listening_session_id: 1, started_at: ~U[2026-03-24 10:00:00Z], start_ms: 0}
      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert "can't be blank" in errors_on(changeset).end_ms
    end

    test "invalid when listening_session_id is missing" do
      attrs = %{started_at: ~U[2026-03-24 10:00:00Z], start_ms: 0, end_ms: 3000}
      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert "can't be blank" in errors_on(changeset).listening_session_id
    end

    test "invalid when start_ms is negative" do
      attrs = %{
        listening_session_id: 1,
        started_at: ~U[2026-03-24 10:00:00Z],
        start_ms: -1,
        end_ms: 3000
      }

      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert errors_on(changeset).start_ms != []
    end

    test "invalid when end_ms is not greater than start_ms" do
      attrs = %{
        listening_session_id: 1,
        started_at: ~U[2026-03-24 10:00:00Z],
        start_ms: 5000,
        end_ms: 5000
      }

      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert "must be greater than start_ms" in errors_on(changeset).end_ms
    end

    test "invalid when end_ms is less than start_ms" do
      attrs = %{
        listening_session_id: 1,
        started_at: ~U[2026-03-24 10:00:00Z],
        start_ms: 5000,
        end_ms: 3000
      }

      changeset = SpeechMarker.changeset(%SpeechMarker{}, attrs)
      assert "must be greater than start_ms" in errors_on(changeset).end_ms
    end
  end

  describe "add_speech_marker/4" do
    setup do
      user = user_fixture(%{role: :streamer})
      {:ok, album} = PremiereEcoute.Discography.Album.create(album_fixture())

      {:ok, session} =
        ListeningSession.create(%{
          user_id: user.id,
          album_id: album.id,
          started_at: ~U[2026-03-24 10:00:00Z]
        })

      {:ok, session: %{session | started_at: ~U[2026-03-24 10:00:00Z]}}
    end

    test "inserts a speech marker with correct offsets", %{session: session} do
      assert {:ok, marker} = ListeningSession.add_speech_marker(session, 5000, 8500, "hello")

      assert marker.listening_session_id == session.id
      assert marker.start_ms == 5000
      assert marker.end_ms == 8500
      assert marker.text == "hello"
      assert marker.started_at == ~U[2026-03-24 10:00:05Z]
    end

    test "inserts a speech marker without text (async fill pattern)", %{session: session} do
      assert {:ok, marker} = ListeningSession.add_speech_marker(session, 0, 2000)

      assert marker.text == nil
      assert marker.start_ms == 0
      assert marker.end_ms == 2000
    end

    test "returns error for invalid offsets", %{session: session} do
      assert {:error, changeset} = ListeningSession.add_speech_marker(session, 5000, 5000)
      assert "must be greater than start_ms" in errors_on(changeset).end_ms
    end

    test "speech markers are preloaded on session", %{session: session} do
      {:ok, _} = ListeningSession.add_speech_marker(session, 1000, 3000, "first")
      {:ok, _} = ListeningSession.add_speech_marker(session, 5000, 7000, "second")

      loaded = ListeningSession.get(session.id)
      assert length(loaded.speech_markers) == 2
    end
  end
end
