defmodule PremiereEcoute.Accounts.Services.AccountDeletionTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Services.AccountDeletion

  describe "delete_account/1" do
    test "do nothing" do
      user = user_fixture()

      assert Accounts.get_user_by_email(user.email)

      :ok = AccountDeletion.delete_account(user)

      refute is_nil(Accounts.get_user_by_email(user.email))
    end
  end

  describe "delete_associated_data/1" do
    test "do nothing" do
      user = user_fixture()

      assert :ok = AccountDeletion.delete_associated_data(user)
    end
  end
end
