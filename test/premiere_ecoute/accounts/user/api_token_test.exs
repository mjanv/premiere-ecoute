defmodule PremiereEcoute.Accounts.ApiTokenTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts

  describe "generate_user_api_token/1" do
    test "returns a base64-encoded string" do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)
      assert is_binary(token)
      assert {:ok, _} = Base.url_decode64(token, padding: false)
    end
  end

  describe "get_user_by_api_token/1" do
    test "returns the user for a valid token" do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)
      assert {found_user, _inserted_at} = Accounts.get_user_by_api_token(token)
      assert found_user.id == user.id
    end

    test "returns nil for an unknown token" do
      unknown = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      assert Accounts.get_user_by_api_token(unknown) == nil
    end

    test "returns nil for a deleted token" do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)
      Accounts.delete_user_api_tokens(user)
      assert Accounts.get_user_by_api_token(token) == nil
    end
  end
end
