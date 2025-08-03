defmodule PremiereEcoute.Accounts.User.OauthTokenTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.OauthToken

  @twitch_token %{
    provider: :twitch,
    user_id: "twitch_user_id",
    username: "twitch_username",
    access_token: "twitch_access_token",
    refresh_token: "twitch_refresh_token",
    expires_in: 3600
  }

  @spotify_token %{
    provider: :spotify,
    user_id: "spotify_user_id",
    username: "spotify_username",
    access_token: "spotify_access_token",
    refresh_token: "spotify_refresh_token",
    expires_in: 3600
  }

  setup do
    %{user: user_fixture()}
  end

  describe "create/1" do
    test "can create oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, @twitch_token)
      {:ok, user} = OauthToken.create(user, @spotify_token)

      assert %OauthToken{
               provider: :twitch,
               user_id: "twitch_user_id",
               username: "twitch_username",
               access_token: "twitch_access_token",
               refresh_token: "twitch_refresh_token",
               expires_at: _
             } = user.twitch

      assert %OauthToken{
               provider: :spotify,
               user_id: "spotify_user_id",
               username: "spotify_username",
               access_token: "spotify_access_token",
               refresh_token: "spotify_refresh_token",
               expires_at: _
             } = user.spotify
    end
  end

  describe "refresh/1" do
    test "can refresh existing oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, @twitch_token)
      {:ok, user} = OauthToken.create(user, @spotify_token)

      attrs = %{access_token: "new_twitch_access_token", refresh_token: "new_twitch_refresh_token", expires_in: 3600}
      {:ok, user} = OauthToken.refresh(user, :twitch, attrs)

      attrs = %{access_token: "new_spotify_access_token", refresh_token: "new_spotify_refresh_token", expires_in: 3600}
      {:ok, user} = OauthToken.refresh(user, :spotify, attrs)

      assert %OauthToken{
               provider: :twitch,
               user_id: "twitch_user_id",
               username: "twitch_username",
               access_token: "new_twitch_access_token",
               refresh_token: "new_twitch_refresh_token",
               expires_at: _
             } = user.twitch

      assert %OauthToken{
               provider: :spotify,
               user_id: "spotify_user_id",
               username: "spotify_username",
               access_token: "new_spotify_access_token",
               refresh_token: "new_spotify_refresh_token",
               expires_at: _
             } = user.spotify
    end

    test "cannot refresh non-existing oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, @twitch_token)

      attrs = %{access_token: "new_twitch_access_token", refresh_token: "new_twitch_refresh_token", expires_in: 3600}
      {:ok, user} = OauthToken.refresh(user, :twitch, attrs)

      attrs = %{access_token: "new_spotify_access_token", refresh_token: "new_spotify_refresh_token", expires_in: 3600}

      assert {:error, %User{}} = OauthToken.refresh(user, :spotify, attrs)
    end
  end

  describe "disconnect/1" do
    test "can delete oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, @twitch_token)
      {:ok, user} = OauthToken.create(user, @spotify_token)

      {:ok, user} = OauthToken.disconnect(user, :twitch)
      {:ok, user} = OauthToken.disconnect(user, :spotify)

      assert user.twitch == nil
      assert user.spotify == nil
    end

    test "cannnot delete non-existing oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, @twitch_token)

      {:ok, user} = OauthToken.disconnect(user, :twitch)
      {:error, %User{}} = OauthToken.disconnect(user, :spotify)

      assert user.twitch == nil
      assert user.spotify == nil
    end
  end
end
