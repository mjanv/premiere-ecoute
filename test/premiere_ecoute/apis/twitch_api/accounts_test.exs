defmodule PremiereEcoute.Apis.TwitchApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

  describe "client_credentials/0" do
    test "can retrieve access token using client credentials flow" do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/oauth2/token"},
        headers: [{"content-type", "application/x-www-form-urlencoded"}],
        response: "twitch_api/accounts/client_credentials/response.json",
        status: 200
      )

      {:ok, response} = TwitchApi.client_credentials()

      assert %{
        "access_token" => "prau3ol6mg5glgek8m89ec2s9q5i3i",
        "expires_in" => 5011271,
        "token_type" => "bearer"
      } = response
    end
  end

  describe "authorization_code/1" do
    @tag :skip
    test "can exchange authorization code for access token and user data" do
      # Mock the token exchange request
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/oauth2/token"},
        headers: [{"content-type", "application/x-www-form-urlencoded"}],
        response: "twitch_api/accounts/authorization_code/response.json",
        status: 200
      )

      # Mock the user profile request (allowing any headers for debugging)
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/users"},
        response: "twitch_api/users/get_users/response.json",
        status: 200
      )

      {:ok, user_data} = TwitchApi.authorization_code("test_auth_code")

      assert %{
        user_id: "141981764",
        email: "not-real@email.com",
        username: "twitchdev",
        display_name: "TwitchDev",
        broadcaster_type: "partner",
        access_token: "rfx2uswqe8l4g1mkagrvg5tv0ks3",
        refresh_token: "5b93chm6hdve3mycz05zfzatkfdenfspp1h1ar2xxdalen01",
        expires_in: 14124,
        scope: ["user:read:email", "user:read:follows"]
      } = user_data
    end
  end

  describe "renew_token/1" do
    test "can renew access token using refresh token" do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/oauth2/token"},
        headers: [{"content-type", "application/x-www-form-urlencoded"}],
        response: "twitch_api/accounts/renew_token/response.json",
        status: 200
      )

      {:ok, token_data} = TwitchApi.renew_token("old_refresh_token")

      assert %{
        access_token: "1ssjqsqfy6bads1rmgh0rvnvre09kgpz3b",
        refresh_token: "eyJfaWQmNzMtNGCJ9%6VFV5LNrZFUj8oU231/3Aj",
        expires_in: 14124
      } = token_data
    end
  end

  describe "authorization_url/2" do
    test "can generate a valid authorization url for Twitch login" do
      url = TwitchApi.Accounts.authorization_url(nil, "state")

      assert url =~ "https://id.twitch.tv/oauth2/authorize?scope=user%3Aread%3Aemail+user%3Aread%3Afollows"
      assert url =~ "response_type=code"
      assert url =~ "client_id="
      assert url =~ "redirect_uri="
      assert url =~ "state=state"
    end

    test "generates authorization URL with default viewer scope" do
      url = TwitchApi.authorization_url()

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      assert uri.scheme == "https"
      assert uri.host == "id.twitch.tv"
      assert uri.path == "/oauth2/authorize"
      assert query["response_type"] == "code"
      assert query["scope"] == "user:read:email user:read:follows"
      assert query["client_id"] == Application.get_env(:premiere_ecoute, :twitch_client_id)
      assert query["redirect_uri"] == Application.get_env(:premiere_ecoute, :twitch_redirect_uri)
      assert query["state"] != nil
      assert String.length(query["state"]) == 16
    end

    test "generates authorization URL with streamer scope" do
      url = TwitchApi.authorization_url(:streamer)

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      expected_scope = "user:read:email user:read:follows user:read:chat user:write:chat user:bot channel:manage:polls channel:read:polls channel:bot moderator:manage:announcements"
      assert query["scope"] == expected_scope
    end

    test "generates authorization URL with custom scope" do
      custom_scope = "user:read:email channel:read:polls"
      url = TwitchApi.authorization_url(custom_scope)

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      assert query["scope"] == custom_scope
    end

    test "generates authorization URL with custom state" do
      state = "custom_state_123"
      url = TwitchApi.authorization_url(nil, state)

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      assert query["state"] == state
    end
  end
end
