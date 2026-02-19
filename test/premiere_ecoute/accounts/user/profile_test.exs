defmodule PremiereEcoute.Accounts.User.ProfileTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile

  describe "create/1" do
    test "can create an user with a default user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username"})

      assert %Profile{id: _, color_scheme: :system, language: :en} = user.profile
    end

    test "can create an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username", profile: %{color_scheme: :light, language: :it}})

      assert %Profile{id: _, color_scheme: :light, language: :it} = user.profile
    end
  end

  describe "update/1" do
    test "can update an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username", profile: %{color_scheme: :light, language: :it}})

      {:ok, user} =
        User.update(user, %{email: "user2@email.com", username: "username", profile: %{color_scheme: :dark, language: :en}})

      assert %Profile{id: _, color_scheme: :dark, language: :en} = user.profile
    end
  end

  describe "edit_user_profile/1" do
    test "can update an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username", profile: %{color_scheme: :light, language: :it}})

      {:ok, user} = User.edit_user_profile(user, %{color_scheme: :dark, language: :en})

      assert %Profile{id: _, color_scheme: :dark, language: :en} = user.profile
    end
  end

  describe "get/1" do
    test "can get" do
      {:ok, user} =
        User.create(%{
          email: "user@email.com",
          username: "username",
          profile: %{color_scheme: :light, language: :it, radio_settings: %{visibility: :private}}
        })

      assert Profile.get(user, [:language]) == :it
      assert Profile.get(user, [:radio_settings, :unknown]) == nil
      assert Profile.get(user, [:radio_settings, :unknown], :default) == :default
    end
  end
end
