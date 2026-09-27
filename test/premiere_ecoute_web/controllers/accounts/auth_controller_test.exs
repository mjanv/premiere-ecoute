defmodule PremiereEcouteWeb.Accounts.AuthControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi

  setup {Req.Test, :verify_on_exit!}

  defp expect_spotify_token_exchange do
    ApiMock.expect(
      SpotifyApi,
      path: {:post, "/api/token"},
      response: "spotify_api/accounts/authorization_code/response.json",
      status: 200
    )

    ApiMock.expect(
      SpotifyApi,
      path: {:get, "/v1/me"},
      response: "spotify_api/users/get_current_user_profile/response.json",
      status: 200
    )
  end

  defp state_from_redirect(conn) do
    conn
    |> redirected_to()
    |> URI.parse()
    |> Map.fetch!(:query)
    |> URI.decode_query()
    |> Map.fetch!("state")
  end

  describe "Spotify OAuth" do
    setup :register_and_log_in_user

    test "links the Spotify account of the logged-in user", %{conn: conn, user: user} do
      user_token = get_session(conn, :user_token)

      conn = get(conn, ~p"/auth/spotify")
      state = state_from_redirect(conn)

      assert state != to_string(user.id)
      assert get_session(conn, :spotify_oauth_state) == state

      expect_spotify_token_exchange()
      conn = get(conn, ~p"/auth/spotify/callback?code=code&state=#{state}")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token) == user_token
      refute get_session(conn, :spotify_oauth_state)
      assert %{spotify: %{user_id: "lanfeust313"}} = Accounts.get_user!(user.id)
    end

    test "rejects a state that was not issued to the session", %{conn: conn, user: user} do
      admin = user_fixture(%{role: :admin})

      conn = get(conn, ~p"/auth/spotify")
      conn = get(conn, ~p"/auth/spotify/callback?code=code&state=#{admin.id}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to connect Spotify account"
      assert %{spotify: nil} = Accounts.get_user!(user.id)
      assert %{spotify: nil} = Accounts.get_user!(admin.id)
    end

    test "rejects a callback without a state in session", %{conn: conn, user: user} do
      conn = get(conn, ~p"/auth/spotify/callback?code=code&state=#{user.id}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to connect Spotify account"
      assert %{spotify: nil} = Accounts.get_user!(user.id)
    end

    test "rejects a replayed state", %{conn: conn} do
      conn = get(conn, ~p"/auth/spotify")
      state = state_from_redirect(conn)

      expect_spotify_token_exchange()
      conn = get(conn, ~p"/auth/spotify/callback?code=code&state=#{state}")
      assert redirected_to(conn) == ~p"/"

      conn = get(conn, ~p"/auth/spotify/callback?code=code&state=#{state}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to connect Spotify account"
    end
  end

  describe "Spotify OAuth without a logged-in user" do
    test "does not start the authorization flow", %{conn: conn} do
      conn = get(conn, ~p"/auth/spotify")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You must be logged in to connect Spotify"
      refute get_session(conn, :spotify_oauth_state)
    end

    test "does not log anyone in, even with a valid state", %{conn: conn} do
      user = user_fixture(%{role: :admin})

      conn =
        conn
        |> init_test_session(%{spotify_oauth_state: "state"})
        |> get(~p"/auth/spotify/callback?code=code&state=state")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to connect Spotify account"
      refute get_session(conn, :user_token)
      assert %{spotify: nil} = Accounts.get_user!(user.id)
    end
  end
end
