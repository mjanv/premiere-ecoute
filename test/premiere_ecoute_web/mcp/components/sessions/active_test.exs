defmodule PremiereEcouteWeb.Mcp.Components.Sessions.ActiveTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures
  import PremiereEcoute.Discography.AlbumFixtures
  import PremiereEcoute.Sessions.ListeningSessionFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcouteWeb.Mcp.Components.Sessions.Active

  defp authenticated_frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  defp with_role(user, role) do
    {:ok, user} = User.update_user_role(user, role)
    user
  end

  describe "RBAC" do
    test "returns forbidden for viewer role" do
      user = user_fixture()
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"error" => "forbidden"}} = Jason.decode(json)
    end

    test "returns forbidden for bot role" do
      user = user_fixture() |> with_role(:bot)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"error" => "forbidden"}} = Jason.decode(json)
    end

    test "allows streamer role" do
      user = user_fixture() |> with_role(:streamer)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, data} = Jason.decode(json)
      refute Map.has_key?(data, "error")
    end

    test "allows admin role" do
      user = user_fixture() |> with_role(:admin)
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, data} = Jason.decode(json)
      refute Map.has_key?(data, "error")
    end
  end

  describe "read/2" do
    setup do
      user = user_fixture() |> with_role(:streamer)

      {:ok, album} =
        Album.create(album_fixture(%{provider_ids: %{spotify: "mcp-active-test-#{System.unique_integer([:positive])}"}}))

      {:ok, user: user, album: album}
    end

    test "returns active: false when no active session", %{user: user} do
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"active" => false}} = Jason.decode(json)
    end

    test "returns active: true with session data for active session", %{user: user, album: album} do
      session =
        session_fixture(%{
          user_id: user.id,
          album_id: album.id,
          status: :active,
          started_at: ~U[2026-01-01 20:00:00Z]
        })

      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"active" => true, "session" => s}} = Jason.decode(json)
      assert s["id"] == session.id
      assert s["status"] == "active"
      assert s["source"] == "album"
    end

    test "returns active: false for a preparing session", %{user: user, album: album} do
      session_fixture(%{user_id: user.id, album_id: album.id, status: :preparing})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"active" => false}} = Jason.decode(json)
    end

    test "includes current_track when set", %{user: user, album: album} do
      session = session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
      track = List.first(Repo.preload(album, :tracks).tracks)
      {:ok, _} = ListeningSession.changeset(session, %{current_track_id: track.id}) |> Repo.update()

      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"active" => true, "session" => s}} = Jason.decode(json)
      assert %{"name" => name, "number" => number} = s["current_track"]
      assert name == track.name
      assert number == track.track_number
    end

    test "returns nil current_track when no track set", %{user: user, album: album} do
      session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"active" => true, "session" => s}} = Jason.decode(json)
      assert is_nil(s["current_track"])
    end

    test "exposes vote_options and options", %{user: user, album: album} do
      session_fixture(%{user_id: user.id, album_id: album.id, status: :active})
      frame = authenticated_frame(user)

      assert {:reply, resp, ^frame} = Active.read(%{}, frame)
      assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
      assert {:ok, %{"session" => s}} = Jason.decode(json)
      assert is_list(s["vote_options"])
      assert is_map(s["options"])
    end
  end
end
