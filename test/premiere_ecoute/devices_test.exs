defmodule PremiereEcoute.DevicesTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures
  import PremiereEcoute.PlayerFixtures

  alias Boruta.Oauth.Authorization.AccessToken
  alias PremiereEcoute.Devices

  describe "revoke_player/1" do
    test "invalidates the access and refresh tokens of the user's player" do
      user = user_fixture()
      %{access_token: access_token, refresh_token: refresh_token} = player_tokens(user)

      assert :ok = Devices.revoke_player(user)

      assert {:error, _} = AccessToken.authorize(value: access_token)
      assert {:error, _} = AccessToken.authorize(refresh_token: refresh_token)
    end

    test "leaves the players of other users untouched" do
      user = user_fixture()
      other = user_fixture()
      player_tokens(user)
      %{access_token: other_access_token} = player_tokens(other)

      assert :ok = Devices.revoke_player(user)

      assert {:ok, _} = AccessToken.authorize(value: other_access_token)
    end

    test "succeeds when the user never enrolled a player" do
      assert :ok = Devices.revoke_player(user_fixture())
    end
  end

  describe "player_enrolled?/1" do
    test "is true while the user holds a usable player refresh token" do
      user = user_fixture()
      refute Devices.player_enrolled?(user)

      player_tokens(user)
      assert Devices.player_enrolled?(user)

      :ok = Devices.revoke_player(user)
      refute Devices.player_enrolled?(user)
    end

    test "ignores the players of other users" do
      player_tokens(user_fixture())

      refute Devices.player_enrolled?(user_fixture())
    end
  end
end
