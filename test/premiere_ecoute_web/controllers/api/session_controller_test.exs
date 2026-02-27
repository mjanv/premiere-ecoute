defmodule PremiereEcouteWeb.Api.SessionControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcouteCore.CommandBus.Mock, as: CommandBus

  setup {PremiereEcoute.Sessions, :mock}
  setup {PremiereEcouteCore.CommandBus, :mock}

  defp api_conn(conn, user) do
    token = Accounts.generate_user_api_token(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

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

      expect(CommandBus, :apply, fn %StopListeningSession{
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

      expect(CommandBus, :apply, fn %SkipNextTrackListeningSession{
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

      expect(CommandBus, :apply, fn %SkipPreviousTrackListeningSession{
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

  describe "POST /api/session/vote" do
    test "publishes MessageSent with the given rating and returns ok", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "streamer123"}})

      expect(Sessions.Mock, :publish_message, fn %MessageSent{
                                                   broadcaster_id: broadcaster_id,
                                                   user_id: user_id,
                                                   message: message,
                                                   is_streamer: is_streamer
                                                 } ->
        assert broadcaster_id == "streamer123"
        assert user_id == "streamer123"
        assert message == "7"
        assert is_streamer == true
        :ok
      end)

      response =
        conn
        |> api_conn(user)
        |> post(~p"/api/session/vote", %{rating: 7})
        |> json_response(200)

      assert response["ok"] == true
      assert response["rating"] == 7
    end

    test "returns 422 when rating is out of range", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "streamer123"}})

      conn
      |> api_conn(user)
      |> post(~p"/api/session/vote", %{rating: 11})
      |> json_response(422)
    end

    test "returns 422 when rating param is missing", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "streamer123"}})

      conn
      |> api_conn(user)
      |> post(~p"/api/session/vote", %{})
      |> json_response(422)
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
