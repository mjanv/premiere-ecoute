defmodule PremiereEcouteWeb.Sessions.DashboardLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import PremiereEcoute.Sessions.ListeningSessionFixtures

  alias PremiereEcouteCore.Cache

  setup do
    start_supervised(PremiereEcoute.Apis.PlayerSupervisor)
    start_supervised({Cache, name: :sessions})
    :ok
  end

  describe "mount authorization" do
    test "redirects a streamer who does not own the session", %{conn: conn} do
      owner = user_fixture(%{role: :streamer, spotify: %{}})
      other = user_fixture(%{role: :streamer, spotify: %{}, twitch: %{user_id: "other-twitch-id"}})

      session = session_fixture(%{user_id: owner.id})

      conn = log_in_user(conn, other)

      assert {:error, {:redirect, %{to: "/sessions"}}} = live(conn, ~p"/sessions/#{session.share_token}/dashboard")
    end

    test "allows the owning streamer to mount the dashboard", %{conn: conn} do
      owner = user_fixture(%{role: :streamer, spotify: %{}, twitch: %{user_id: "owner-twitch-id"}})

      session =
        session_fixture(%{user_id: owner.id, source: :free, album_id: nil, name: "Free session", vote_mode: :chat})

      conn = log_in_user(conn, owner)

      assert {:ok, _view, _html} = live(conn, ~p"/sessions/#{session.share_token}/dashboard")
    end
  end
end
