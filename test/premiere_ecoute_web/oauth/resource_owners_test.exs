defmodule PremiereEcouteWeb.Oauth.ResourceOwnersTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Boruta.Oauth.ResourceOwner
  alias PremiereEcouteWeb.Oauth.ResourceOwners

  describe "get_by/1" do
    test "finds a user by sub (id)" do
      user = user_fixture()

      assert {:ok, %ResourceOwner{sub: sub, username: username}} = ResourceOwners.get_by(sub: to_string(user.id))
      assert sub == to_string(user.id)
      assert username == user.email
    end

    test "finds a user by email" do
      user = user_fixture()

      assert {:ok, %ResourceOwner{sub: sub}} = ResourceOwners.get_by(email: user.email)
      assert sub == to_string(user.id)
    end

    test "returns an error when the sub does not match any user" do
      assert {:error, _reason} = ResourceOwners.get_by(sub: "0")
    end

    test "returns an error when the email does not match any user" do
      assert {:error, _reason} = ResourceOwners.get_by(email: "nobody@example.com")
    end
  end

  describe "check_password/2" do
    test "is not supported" do
      assert {:error, _reason} = ResourceOwners.check_password(%ResourceOwner{sub: "1"}, "irrelevant")
    end
  end

  describe "authorized_scopes/1" do
    test "returns no pre-authorized scopes" do
      assert ResourceOwners.authorized_scopes(%ResourceOwner{sub: "1"}) == []
    end
  end

  describe "claims/2" do
    test "returns standard claims for an existing user" do
      user = user_fixture()

      claims = ResourceOwners.claims(%ResourceOwner{sub: to_string(user.id)}, "mcp")

      assert claims.sub == to_string(user.id)
      assert claims.preferred_username == user.username
      assert claims.email == user.email
    end

    test "returns an empty map when the user no longer exists" do
      assert ResourceOwners.claims(%ResourceOwner{sub: "0"}, "mcp") == %{}
    end
  end
end
