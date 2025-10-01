defmodule PremiereEcoute.Apis.SpotifyApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi

  describe "client_credentials/0" do
    test "can retrieve access token using client credentials flow" do
      client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "spotify_api/accounts/client_credentials/response.json",
        status: 200
      )

      {:ok, response} = SpotifyApi.Accounts.client_credentials()

      assert %{
        "access_token" => "BQCKrzBNz_WbxC0HsGUMcTKVe9VzOL-dKRXlFY4wTwdE1KjKv3Kx_0Q5...",
        "token_type" => "Bearer",
        "expires_in" => 3600
      } = response
    end
  end

  describe "authorization_code/2" do
    test "can exchange authorization code for access token and user profile" do
      client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
      auth_header = Base.encode64("#{client_id}:#{Application.get_env(:premiere_ecoute, :spotify_client_secret)}")

      # Mock the token exchange request
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "spotify_api/accounts/authorization_code/response.json",
        status: 200
      )

      # Mock the user profile request
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me"},
        headers: [
          {"authorization", "Bearer NgCXRK...MzYjw"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/users/get_current_user_profile/response.json",
        status: 200
      )

      {:ok, user_data} = SpotifyApi.Accounts.authorization_code("test_auth_code", "test_state")

      assert %{
        user_id: "lanfeust313",
        email: "maxime.janvier@gmail.com",
        username: "lanfeust313",
        display_name: "lanfeust313",
        country: "FR",
        product: "premium",
        access_token: "NgCXRK...MzYjw",
        refresh_token: "NgAagA...Um_SHo",
        expires_in: 3600
      } = user_data
    end
  end

  describe "renew_token/1" do
    test "can renew access token with refresh token" do
      client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "spotify_api/accounts/renew_token/success_response.json",
        status: 200
      )

      {:ok, token_data} = SpotifyApi.Accounts.renew_token("old_refresh_token")

      assert %{
        access_token: "NgCXRKjs...HIjw",
        refresh_token: "NgAagAAU...SHo",
        expires_in: 3600
      } = token_data
    end

    test "can renew access token when no new refresh token is provided" do
      client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "spotify_api/accounts/renew_token/success_response_no_new_refresh.json",
        status: 200
      )

      {:ok, token_data} = SpotifyApi.Accounts.renew_token("original_refresh_token")

      assert %{
        access_token: "NgCXRKjs...HIjw",
        refresh_token: "original_refresh_token",
        expires_in: 3600
      } = token_data
    end

    test "returns error when token refresh fails with HTTP error" do
      client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/api/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "spotify_api/accounts/renew_token/error_response.json",
        status: 400
      )

      {:error, error_message} = SpotifyApi.Accounts.renew_token("invalid_refresh_token")

      assert error_message =~ "Spotify token refresh failed: 400"
      assert error_message =~ "invalid_grant"
    end
  end

  describe "authorization_url/0" do
    test "can generate a valid authorization url for Spotify login" do
      url = SpotifyApi.Accounts.authorization_url()

      assert url =~
               "https://accounts.spotify.com/authorize?scope=user-read-private+user-read-email"

      assert url =~ "response_type=code"
      assert url =~ "client_id="
      assert url =~ "redirect_uri="
      assert url =~ "state="
    end
  end
end
