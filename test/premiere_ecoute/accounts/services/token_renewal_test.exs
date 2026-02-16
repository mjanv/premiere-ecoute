defmodule PremiereEcoute.Accounts.Services.TokenRenewalTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.{Scope, User}
  alias PremiereEcoute.Accounts.Services.TokenRenewal
  alias PremiereEcoute.Accounts.User.OauthToken

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  setup do
    stub(SpotifyApi, :renew_token, fn _refresh_token ->
      {:ok, %{access_token: "new_access_token", refresh_token: "new_refresh_token", expires_in: 3600}}
    end)

    stub(TwitchApi, :renew_token, fn _refresh_token ->
      {:ok, %{access_token: "new_access_token", refresh_token: "new_refresh_token", expires_in: 3600}}
    end)

    user = user_fixture()
    scope = Scope.for_user(user)
    conn = %Plug.Conn{assigns: %{current_scope: scope}}

    %{user: user, scope: scope, conn: conn}
  end

  describe "maybe_renew_token/2" do
    test "renews expired Spotify token successfully", %{user: user, conn: conn} do
      {:ok, user} =
        OauthToken.create(user, :spotify, %{
          user_id: "spotify_user_id",
          username: "spotify_username",
          access_token: "old_access_token",
          refresh_token: "old_refresh_token",
          expires_in: -3600
        })

      conn = put_in(conn.assigns.current_scope.user, user)

      result = TokenRenewal.maybe_renew_token(conn, :spotify)

      assert %Scope{user: %User{spotify: %OauthToken{access_token: "new_access_token"}}} = result
    end

    test "renews expired Twitch token successfully", %{user: user, conn: conn} do
      {:ok, user} =
        OauthToken.create(user, :twitch, %{
          user_id: "twitch_user_id",
          username: "twitch_username",
          access_token: "old_access_token",
          refresh_token: "old_refresh_token",
          expires_in: -3600
        })

      conn = put_in(conn.assigns.current_scope.user, user)

      result = TokenRenewal.maybe_renew_token(conn, :twitch)

      assert %Scope{user: %User{twitch: %OauthToken{access_token: "new_access_token"}}} = result
    end

    test "does not renew non-expired token", %{user: user, conn: conn} do
      {:ok, user} =
        OauthToken.create(user, :spotify, %{
          user_id: "spotify_user_id",
          username: "spotify_username",
          access_token: "current_access_token",
          refresh_token: "current_refresh_token",
          expires_in: 3600
        })

      conn = put_in(conn.assigns.current_scope.user, user)

      result = TokenRenewal.maybe_renew_token(conn, :spotify)

      assert %Scope{user: %User{spotify: %OauthToken{access_token: "current_access_token"}}} = result
    end

    test "returns original scope when user has no token for provider", %{conn: conn, scope: scope} do
      new_scope = TokenRenewal.maybe_renew_token(conn, :spotify)

      assert new_scope == scope
    end

    test "returns original scope when no current_scope in conn" do
      conn = %Plug.Conn{assigns: %{}}

      scope = TokenRenewal.maybe_renew_token(conn, :spotify)

      assert is_nil(scope)
    end

    test "returns original scope when user is nil in scope", %{conn: conn} do
      scope = %Scope{user: nil}
      conn = put_in(conn.assigns.current_scope, scope)

      scope = TokenRenewal.maybe_renew_token(conn, :spotify)

      assert %Scope{user: nil} = scope
    end

    test "handles API renewal failure gracefully", %{user: user, conn: conn} do
      stub(SpotifyApi, :renew_token, fn _refresh_token -> {:error, "Nope"} end)

      {:ok, user} =
        OauthToken.create(user, :spotify, %{
          user_id: "spotify_user_id",
          username: "spotify_username",
          access_token: "old_access_token",
          refresh_token: "old_refresh_token",
          expires_in: 0,
          expired_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        })

      conn = put_in(conn.assigns.current_scope.user, user)

      scope = TokenRenewal.maybe_renew_token(conn, :spotify)

      assert %Scope{user: %User{spotify: %OauthToken{access_token: "old_access_token"}}} = scope
    end
  end

  describe "token_expired?/1" do
    test "returns false for nil expires_at" do
      refute TokenRenewal.token_expired?(nil)
    end

    test "returns true for expired token (beyond 5 minute buffer)" do
      expired_time = DateTime.utc_now() |> DateTime.add(-600, :second)
      assert TokenRenewal.token_expired?(expired_time)
    end

    test "returns true for token expiring within 5 minutes" do
      expiring_soon = DateTime.utc_now() |> DateTime.add(240, :second)
      assert TokenRenewal.token_expired?(expiring_soon)
    end

    test "returns false for token with more than 5 minutes remaining" do
      valid_time = DateTime.utc_now() |> DateTime.add(600, :second)
      refute TokenRenewal.token_expired?(valid_time)
    end

    test "returns true for token exactly at 5 minute threshold" do
      threshold_time = DateTime.utc_now() |> DateTime.add(300, :second)
      assert TokenRenewal.token_expired?(threshold_time)
    end

    test "returns false for token just over 5 minute threshold" do
      just_over_threshold = DateTime.utc_now() |> DateTime.add(301, :second)
      refute TokenRenewal.token_expired?(just_over_threshold)
    end
  end
end
