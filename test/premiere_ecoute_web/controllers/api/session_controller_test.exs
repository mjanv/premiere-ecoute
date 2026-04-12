defmodule PremiereEcouteWeb.Api.SessionControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcouteCore.CommandBus.Mock, as: CommandBus

  setup_mock(PremiereEcoute.Sessions)
  setup_mock(PremiereEcouteCore.CommandBus)

  describe "POST /api/session/start" do
    test "dispatches StartListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :preparing})

      expect(CommandBus, :apply, fn %StartListeningSession{
                                      session_id: session_id,
                                      source: source
                                    } ->
        assert session_id == session.id
        assert source == session.source
        {:ok, session, []}
      end)

      expect(CommandBus, :apply, fn %SkipNextTrackListeningSession{
                                      session_id: session_id,
                                      source: source
                                    } ->
        assert session_id == session.id
        assert source == session.source
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/session/start")
      |> response(200, op(SessionController, :start))
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> auth(user)
      |> post(~p"/api/session/start")
      |> json_response(404)
    end
  end

  describe "POST /api/session/stop" do
    test "dispatches StopListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      expect(CommandBus, :apply, fn %StopListeningSession{
                                      session_id: session_id
                                    } ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/session/stop")
      |> response(200, op(SessionController, :stop))
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> auth(user)
      |> post(~p"/api/session/stop")
      |> json_response(404)
    end
  end

  describe "POST /api/session/next" do
    test "dispatches SkipNextTrackListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      expect(CommandBus, :apply, fn %SkipNextTrackListeningSession{
                                      session_id: session_id
                                    } ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/session/next")
      |> response(200, op(SessionController, :next))
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> auth(user)
      |> post(~p"/api/session/next")
      |> json_response(404)
    end
  end

  describe "POST /api/session/previous" do
    test "dispatches SkipPreviousTrackListeningSession command and returns ok", %{conn: conn} do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      expect(CommandBus, :apply, fn %SkipPreviousTrackListeningSession{
                                      session_id: session_id
                                    } ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/session/previous")
      |> response(200, op(SessionController, :previous))
    end

    test "returns 404 when no session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> auth(user)
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
        |> auth(user)
        |> get(~p"/api/session")
        |> response(200, op(SessionController, :show))

      assert response["id"] == session.id
      assert response["status"] == "active"
    end

    test "returns 404 when no active session exists", %{conn: conn} do
      user = user_fixture()

      conn
      |> auth(user)
      |> get(~p"/api/session")
      |> json_response(404)
    end
  end
end
