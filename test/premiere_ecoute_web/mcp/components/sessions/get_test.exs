defmodule PremiereEcouteWeb.Mcp.Components.Sessions.GetTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures
  import PremiereEcoute.Discography.AlbumFixtures
  import PremiereEcoute.Sessions.ListeningSessionFixtures
  import PremiereEcoute.Sessions.ScoresFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcouteWeb.Mcp.Components.Sessions.Get

  defp authenticated_frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  defp with_role(user, role) do
    {:ok, user} = User.update_user_role(user, role)
    user
  end

  defp unique_album do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "get-test-#{System.unique_integer([:positive])}"}}))

    album
  end

  defp decode_tool_response(resp) do
    [%{"text" => json}] = resp.content
    Jason.decode!(json)
  end

  describe "RBAC" do
    test "returns forbidden for viewer role" do
      user = user_fixture()
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: 1}, frame)
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Forbidden"
    end

    test "returns forbidden for bot role" do
      user = user_fixture() |> with_role(:bot)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: 1}, frame)
      assert resp.isError == true
    end

    test "allows streamer role (session not found is ok)" do
      user = user_fixture() |> with_role(:streamer)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: 0}, frame)
      assert [%{"text" => msg}] = resp.content
      refute msg =~ "Forbidden"
    end

    test "allows admin role (session not found is ok)" do
      user = user_fixture() |> with_role(:admin)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: 0}, frame)
      assert [%{"text" => msg}] = resp.content
      refute msg =~ "Forbidden"
    end
  end

  describe "execute/2" do
    setup do
      user = user_fixture() |> with_role(:streamer)
      album = unique_album()
      {:ok, user: user, album: album}
    end

    test "returns not found for unknown session id", %{user: user} do
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: 0}, frame)
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "not found"
    end

    test "returns not found for a session owned by another user", %{user: user, album: album} do
      other_user = user_fixture() |> with_role(:streamer)
      session = session_fixture(%{user_id: other_user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: session.id}, frame)
      assert resp.isError == true
    end

    test "returns error for a non-stopped session", %{user: user, album: album} do
      session = session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: session.id}, frame)
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "not stopped"
    end

    test "returns session payload with expected fields", %{user: user, album: album} do
      session = session_fixture(%{user_id: user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: session.id}, frame)
      refute resp.isError
      data = decode_tool_response(resp)
      assert data["id"] == session.id
      assert data["source"] == "album"
      assert data["status"] == "stopped"
      assert data["title"] == album.name
      assert is_list(data["track_markers"])
    end

    test "includes track markers when present", %{user: user, album: album} do
      album_with_tracks = Repo.preload(album, :tracks)
      track = List.first(album_with_tracks.tracks)

      session =
        session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
        |> ListeningSession.changeset(%{current_track_id: track.id})
        |> Repo.update!()
        |> Repo.preload([:track_markers, :current_track])

      {:ok, _marker} = ListeningSession.add_track_marker(session)

      {:ok, stopped_session} =
        session
        |> ListeningSession.changeset(%{status: :stopped})
        |> Repo.update()

      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: stopped_session.id}, frame)
      data = decode_tool_response(resp)
      assert [marker] = data["track_markers"]
      assert marker["track_number"] == track.track_number
    end

    test "includes scores when votes exist", %{user: user, album: album} do
      album_with_tracks = Repo.preload(album, :tracks)
      track = List.first(album_with_tracks.tracks)

      session =
        session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
        |> ListeningSession.changeset(%{current_track_id: track.id})
        |> Repo.update!()

      vote_fixture(%{
        viewer_id: "twitch-viewer-#{System.unique_integer([:positive])}",
        session_id: session.id,
        track_id: track.id,
        value: "8"
      })

      {:ok, stopped_session} =
        session
        |> ListeningSession.changeset(%{status: :stopped})
        |> Repo.update()

      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: stopped_session.id}, frame)
      data = decode_tool_response(resp)
      assert %{"session_summary" => summary, "track_summaries" => [track_summary]} = data["scores"]
      assert summary["unique_votes"] == 1
      assert track_summary["track_id"] == track.id
    end

    test "scores is nil for free sessions", %{user: user} do
      session = session_fixture(%{user_id: user.id, status: :stopped, source: :free, name: "My session"})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Get.execute(%{session_id: session.id}, frame)
      data = decode_tool_response(resp)
      assert is_nil(data["scores"])
      assert data["title"] == "My session"
    end
  end
end
