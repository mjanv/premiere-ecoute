defmodule PremiereEcouteWeb.Mcp.ServerTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcouteWeb.Mcp.Server

  describe "authenticate/2 via x-api-key" do
    test "authenticates the user for a valid API token" do
      user = user_fixture()
      api_key = Token.generate_user_api_token(user)

      assert {:ok, authenticated} = Server.authenticate([api_key], nil)
      assert authenticated.id == user.id
    end

    test "falls through to bearer token check for an invalid API token" do
      assert Server.authenticate(["not-a-valid-token"], nil) == :error
    end

    test "rejects when no headers are present at all" do
      assert Server.authenticate(nil, nil) == :error
    end
  end

  describe "authenticate/2 via Authorization Bearer header" do
    test "rejects a missing authorization header" do
      assert Server.authenticate(nil, nil) == :error
    end

    test "rejects an authorization header without the Bearer scheme" do
      assert Server.authenticate(nil, ["Basic dXNlcjpwYXNz"]) == :error
    end

    test "rejects a malformed bearer token" do
      assert Server.authenticate(nil, ["Bearer not-a-real-oauth-token"]) == :error
    end

    test "rejects multiple authorization headers" do
      assert Server.authenticate(nil, ["Bearer one", "Bearer two"]) == :error
    end

    # AIDEV-NOTE: the happy path (a real Boruta access token resolving to a user) requires the
    # boruta_* tables from `mix boruta.gen.migration` to exist; add an integration test alongside
    # that migration once it's generated.
  end
end
