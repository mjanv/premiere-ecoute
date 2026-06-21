defmodule PremiereEcouteWeb.Mcp.Components.Sessions.SearchTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures
  import PremiereEcoute.Discography.AlbumFixtures
  import PremiereEcoute.Sessions.ListeningSessionFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcouteWeb.Mcp.Components.Sessions.Search

  defp authenticated_frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  defp with_role(user, role) do
    {:ok, user} = User.update_user_role(user, role)
    user
  end

  defp unique_album do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "search-test-#{System.unique_integer([:positive])}"}}))

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

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Forbidden"
    end

    test "returns forbidden for bot role" do
      user = user_fixture() |> with_role(:bot)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert resp.isError == true
    end

    test "allows streamer role" do
      user = user_fixture() |> with_role(:streamer)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      refute resp.isError
    end

    test "allows admin role" do
      user = user_fixture() |> with_role(:admin)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      refute resp.isError
    end
  end

  describe "execute/2" do
    setup do
      user = user_fixture() |> with_role(:streamer)
      album = unique_album()
      {:ok, user: user, album: album}
    end

    test "returns empty list when user has no stopped sessions", %{user: user} do
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert %{"sessions" => []} = decode_tool_response(resp)
    end

    test "returns stopped sessions for the user", %{user: user, album: album} do
      session = session_fixture(%{user_id: user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert %{"sessions" => [s]} = decode_tool_response(resp)
      assert s["id"] == session.id
      assert s["source"] == "album"
      assert s["title"] == album.name
    end

    test "does not return sessions from other users", %{user: user, album: album} do
      other_user = user_fixture() |> with_role(:streamer)
      session_fixture(%{user_id: other_user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert %{"sessions" => []} = decode_tool_response(resp)
    end

    test "does not return active or preparing sessions", %{user: user, album: album} do
      session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
      session_fixture(%{user_id: user.id, album_id: album.id, status: :preparing})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert %{"sessions" => []} = decode_tool_response(resp)
    end

    test "respects the limit param", %{user: user, album: album} do
      for _ <- 1..5, do: session_fixture(%{user_id: user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{limit: 3}, frame)
      assert %{"sessions" => sessions} = decode_tool_response(resp)
      assert length(sessions) == 3
    end

    test "caps limit at 50", %{user: user, album: album} do
      for _ <- 1..3, do: session_fixture(%{user_id: user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{limit: 9999}, frame)
      assert %{"sessions" => sessions} = decode_tool_response(resp)
      assert length(sessions) == 3
    end

    test "session payload includes expected fields", %{user: user, album: album} do
      session_fixture(%{user_id: user.id, album_id: album.id, status: :stopped})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Search.execute(%{}, frame)
      assert %{"sessions" => [s]} = decode_tool_response(resp)
      assert Map.has_key?(s, "id")
      assert Map.has_key?(s, "source")
      assert Map.has_key?(s, "title")
      assert Map.has_key?(s, "started_at")
      assert Map.has_key?(s, "ended_at")
    end
  end
end
