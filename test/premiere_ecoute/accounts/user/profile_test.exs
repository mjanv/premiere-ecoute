defmodule PremiereEcoute.Accounts.User.ProfileTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile

  describe "create/1" do
    test "can create an user with a default user profile" do
      {:ok, user} = User.create(%{email: "user@email.com"})

      assert %Profile{id: _, display_name: nil} = user.profile
    end

    test "can create an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", profile: %{display_name: "User"}})

      assert %Profile{id: _, display_name: "User"} = user.profile
    end
  end

  describe "update/1" do
    test "can update an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", profile: %{display_name: "User"}})

      {:ok, user} = User.update(user, %{email: "user2@email.com", profile: %{display_name: "New User"}})

      assert %Profile{id: _, display_name: "New User"} = user.profile
    end
  end

  describe "edit_user_profile/1" do
    test "can update an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", profile: %{display_name: "User"}})

      {:ok, user} = User.edit_user_profile(user, %{display_name: "New User"})

      assert %Profile{id: _, display_name: "New User"} = user.profile
    end
  end
end
