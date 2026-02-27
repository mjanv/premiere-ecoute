defmodule PremiereEcouteWeb.Api.SessionControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  # AIDEV-NOTE: Commands aliased here are used in Mox.expect pattern matching below

  setup do
    original = Application.get_env(:premiere_ecoute, :command_bus)
    Application.put_env(:premiere_ecoute, :command_bus, PremiereEcoute.CommandBus.Mock)

    on_exit(fn ->
      if original do
        Application.put_env(:premiere_ecoute, :command_bus, original)
      else
        Application.delete_env(:premiere_ecoute, :command_bus)
      end
    end)

    :ok
  end

  defp api_conn(conn, user) do
    token = Accounts.generate_user_api_token(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  describe "POST /api/session/start" do
    test "dispatches StartListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :preparing})

      expect(PremiereEcoute.CommandBus.Mock, :apply, fn %StartListeningSession{
                                                          session_id: session_id,
                                                          source: source
                                                        } ->
        assert session_id == session.id
        assert source == session.source
        {:ok, session, []}
      end)

      expect(PremiereEcoute.CommandBus.Mock, :apply, fn %SkipNextTrackListeningSession{
                                                          session_id: session_id,
                                                          source: source
                                                        } ->
        assert session_id == session.id
        assert source == session.source
        {:ok, session, []}
      end)

      conn
      |> api_conn(user)
      |> post(~p"/api/session/start")
      |> json_response(200)
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> api_conn(user)
      |> post(~p"/api/session/start")
      |> json_response(404)
    end
  end

  describe "POST /api/session/stop" do
    test "dispatches StopListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      expect(PremiereEcoute.CommandBus.Mock, :apply, fn %StopListeningSession{
                                                          session_id: session_id
                                                        } ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> api_conn(user)
      |> post(~p"/api/session/stop")
      |> json_response(200)
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> api_conn(user)
      |> post(~p"/api/session/stop")
      |> json_response(404)
    end
  end

  describe "POST /api/session/next" do
    test "dispatches SkipNextTrackListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      expect(PremiereEcoute.CommandBus.Mock, :apply, fn %SkipNextTrackListeningSession{
                                                          session_id: session_id
                                                        } ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> api_conn(user)
      |> post(~p"/api/session/next")
      |> json_response(200)
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> api_conn(user)
      |> post(~p"/api/session/next")
      |> json_response(404)
    end
  end

  describe "POST /api/session/previous" do
    test "dispatches SkipPreviousTrackListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      expect(PremiereEcoute.CommandBus.Mock, :apply, fn %SkipPreviousTrackListeningSession{
                                                          session_id: session_id
                                                        } ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> api_conn(user)
      |> post(~p"/api/session/previous")
      |> json_response(200)
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> api_conn(user)
      |> post(~p"/api/session/previous")
      |> json_response(404)
    end
  end

  describe "GET /api/session" do
    test "returns the active session when one exists", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      response =
        conn
        |> api_conn(user)
        |> get(~p"/api/session")
        |> json_response(200)

      assert response["id"] == session.id
      assert response["status"] == "active"
    end

    test "returns 404 when no active session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> api_conn(user)
      |> get(~p"/api/session")
      |> json_response(404)
    end
  end
end
