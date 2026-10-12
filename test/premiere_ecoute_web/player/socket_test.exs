defmodule PremiereEcouteWeb.Player.SocketTest do
  use PremiereEcouteWeb.ChannelCase

  import PremiereEcoute.PlayerFixtures

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.Authorization.AccessToken
  alias PremiereEcouteWeb.Player.Socket

  describe "connect/3" do
    test "accepts a valid player token and identifies the user" do
      user = user_fixture()
      %{access_token: token} = player_tokens(user)

      assert {:ok, socket} = connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]})
      assert socket.assigns.user_id == user.id
      assert Socket.id(socket) == "desktop_socket:#{user.id}"
    end

    test "refuses a connection without token or with an unknown token" do
      assert connect(Socket, %{}, connect_info: %{x_headers: []}) == :error
      assert connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", "unknown"}]}) == :error
    end

    test "refuses a valid token that does not carry the player scope" do
      user = user_fixture()

      {:ok, client} =
        Admin.create_client(%{
          name: "connector",
          redirect_uris: ["https://example.com/callback"],
          supported_grant_types: ["authorization_code"],
          pkce: true
        })

      %{access_token: token} = oauth_tokens(user, client.id, "mcp", "https://example.com/callback")

      assert connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]}) == :error
    end

    test "refuses a revoked token" do
      user = user_fixture()
      %{access_token: token} = player_tokens(user)
      {:ok, %{} = boruta_token} = AccessToken.authorize(value: token)
      {:ok, _} = Boruta.AccessTokensAdapter.revoke(boruta_token)

      assert connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]}) == :error
    end
  end
end
