defmodule PremiereEcoute.Sessions.ListeningSessionSummaryTest do
  use PremiereEcoute.DataCase, async: true

  import Ecto.Query

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    user = user_fixture(%{role: :streamer})
    {:ok, album} = Album.create(album_fixture())
    %{user: user, album: album}
  end

  defp create(user, album, attrs \\ %{}) do
    {:ok, session} = ListeningSession.create(Map.merge(%{user_id: user.id, album_id: album.id}, attrs))
    session
  end

  defp set(session, changes) do
    from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: changes)
    ListeningSession.get(session.id)
  end

  describe "current/1" do
    test "is nil when the streamer has no session", %{user: user} do
      assert ListeningSession.current(user) == nil
    end

    test "is the running session", %{user: user, album: album} do
      session = user |> create(album) |> set(status: :active)

      assert %ListeningSession{id: id, status: :active} = ListeningSession.current(user)
      assert id == session.id
    end

    test "is a session prepared in the last two hours", %{user: user, album: album} do
      session = create(user, album)

      assert %ListeningSession{id: id, status: :preparing} = ListeningSession.current(user)
      assert id == session.id
    end

    test "ignores a session prepared long ago and never started", %{user: user, album: album} do
      user |> create(album) |> set(updated_at: DateTime.add(DateTime.utc_now(:second), -3 * 3600))

      assert ListeningSession.current(user) == nil
    end

    test "ignores a stopped session", %{user: user, album: album} do
      user |> create(album) |> set(status: :stopped)

      assert ListeningSession.current(user) == nil
    end

    test "prefers the running session over a prepared one", %{user: user, album: album} do
      create(user, album)
      running = user |> create(album) |> set(status: :active)

      assert %ListeningSession{id: id} = ListeningSession.current(user)
      assert id == running.id
    end

    test "ignores the sessions of other streamers", %{album: album} do
      other = user_fixture(%{role: :streamer})
      other |> create(album) |> set(status: :active)

      assert ListeningSession.current(user_fixture(%{role: :streamer})) == nil
    end
  end

  describe "summary/1" do
    test "says there is no session" do
      assert ListeningSession.summary(nil) == %{state: :none, source: nil, title: nil, track_number: nil, track_count: nil}
    end

    test "describes a running album session with its position", %{user: user, album: album} do
      [first | _] = album.tracks
      session = user |> create(album) |> set(status: :active, current_track_id: first.id)

      assert %{state: :active, source: :album, title: "Sample Album", track_number: 1, track_count: 2} =
               ListeningSession.summary(session)
    end

    test "has no track number before the first track starts", %{user: user, album: album} do
      session = user |> create(album) |> set(status: :active)

      assert %{state: :active, track_number: nil, track_count: 2} = ListeningSession.summary(session)
    end

    test "describes a prepared session", %{user: user, album: album} do
      assert %{state: :preparing, source: :album, title: "Sample Album"} = user |> create(album) |> ListeningSession.summary()
    end

    test "describes a free session by its name, without a position", %{user: user} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :free, name: "Friday blind listen"})

      assert %{source: :free, title: "Friday blind listen", track_number: nil, track_count: nil} =
               session |> set(status: :active) |> ListeningSession.summary()
    end

    test "treats a stopped session as no session", %{user: user, album: album} do
      session = user |> create(album) |> set(status: :stopped)

      assert %{state: :none} = ListeningSession.summary(session)
    end
  end
end
