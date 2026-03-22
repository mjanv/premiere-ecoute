defmodule PremiereEcouteWeb.Api.VoteControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions
  alias PremiereEcouteWeb.Api.VoteController

  setup {PremiereEcoute.Sessions, :mock}

  describe "POST /api/session/vote" do
    test "streamer publishes MessageSent on their own session", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "streamer123"}})

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
        |> auth(user)
        |> post(~p"/api/session/vote", %{rating: 7})
        |> response(200, op(VoteController, :create))

      assert response["ok"] == true
      assert response["rating"] == 7
    end

    test "viewer publishes MessageSent on the broadcaster's session", %{conn: conn} do
      broadcaster = user_fixture(%{role: :streamer, username: "mystreamer", twitch: %{user_id: "streamer123"}})
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer456"}})

      expect(Sessions.Mock, :publish_message, fn %MessageSent{
                                                   broadcaster_id: broadcaster_id,
                                                   user_id: user_id,
                                                   message: message,
                                                   is_streamer: is_streamer
                                                 } ->
        assert broadcaster_id == broadcaster.twitch.user_id
        assert user_id == "viewer456"
        assert message == "8"
        assert is_streamer == false
        :ok
      end)

      response =
        conn
        |> auth(viewer)
        |> post(~p"/api/session/vote", %{rating: 8, username: "mystreamer"})
        |> response(200, op(VoteController, :create))

      assert response["ok"] == true
      assert response["rating"] == 8
    end

    test "viewer returns 404 when username is unknown", %{conn: conn} do
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer456"}})

      conn
      |> auth(viewer)
      |> post(~p"/api/session/vote", %{rating: 5, username: "unknown"})
      |> json_response(404)
    end

    test "viewer returns 422 when username is missing", %{conn: conn} do
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer456"}})

      conn
      |> auth(viewer)
      |> post(~p"/api/session/vote", %{rating: 5})
      |> json_response(422)
    end

    test "returns 422 when rating is out of range", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "streamer123"}})

      conn
      |> auth(user)
      |> post(~p"/api/session/vote", %{rating: 11})
      |> json_response(422)
    end

    test "returns 422 when rating param is missing", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "streamer123"}})

      conn
      |> auth(user)
      |> post(~p"/api/session/vote", %{})
      |> json_response(422)
    end
  end
end
