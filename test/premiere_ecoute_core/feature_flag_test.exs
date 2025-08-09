defmodule PremiereEcouteCore.FeatureFlagTest do
  use PremiereEcoute.DataCase

  alias PremiereEcouteCore.FeatureFlag

  setup do
    viewer = user_fixture(%{role: :viewer, email: "viewer@email.com"})
    admin = user_fixture(%{role: :admin, email: "admin@email.com"})

    {:ok, %{viewer: viewer, admin: admin}}
  end

  describe "enable/2" do
    test "globally" do
      flag1 = FeatureFlag.enabled?(:global_feature)
      FeatureFlag.enable(:global_feature)
      flag2 = FeatureFlag.enabled?(:global_feature)

      assert {flag1, flag2} == {false, true}
    end

    test "per user", %{viewer: viewer, admin: admin} do
      flag11 = FeatureFlag.enabled?(:user_feature, for: viewer)
      flag12 = FeatureFlag.enabled?(:user_feature, for: admin)
      FeatureFlag.enable(:user_feature, for_actor: viewer)
      flag21 = FeatureFlag.enabled?(:user_feature, for: viewer)
      flag22 = FeatureFlag.enabled?(:user_feature, for: admin)

      assert {flag11, flag21} == {false, true}
      assert {flag12, flag22} == {false, false}
    end

    test "per role", %{viewer: viewer, admin: admin} do
      flag11 = FeatureFlag.enabled?(:role_feature, for: viewer)
      flag12 = FeatureFlag.enabled?(:role_feature, for: admin)
      FeatureFlag.enable(:role_feature, for_group: :admin)
      flag21 = FeatureFlag.enabled?(:role_feature, for: viewer)
      flag22 = FeatureFlag.enabled?(:role_feature, for: admin)

      assert {flag11, flag21} == {false, false}
      assert {flag12, flag22} == {false, true}
    end
  end

  describe "disable/2" do
    test "globally" do
      FeatureFlag.enable(:global_feature)
      assert FeatureFlag.enabled?(:global_feature) == true

      FeatureFlag.disable(:global_feature)
      refute FeatureFlag.enabled?(:global_feature)
    end

    test "per user", %{viewer: viewer} do
      FeatureFlag.enable(:user_feature, for_actor: viewer)
      assert FeatureFlag.enabled?(:user_feature, for: viewer) == true

      FeatureFlag.disable(:user_feature, for_actor: viewer)
      refute FeatureFlag.enabled?(:user_feature, for: viewer)
    end

    test "per role", %{admin: admin} do
      FeatureFlag.enable(:role_feature, for_group: :admin)
      assert FeatureFlag.enabled?(:role_feature, for: admin) == true

      FeatureFlag.disable(:role_feature, for_group: :admin)
      refute FeatureFlag.enabled?(:role_feature, for: admin)
    end
  end

  describe "clear/2" do
    test "globally" do
      FeatureFlag.enable(:global_feature)
      assert FeatureFlag.enabled?(:global_feature)

      FeatureFlag.clear(:global_feature)
      refute FeatureFlag.enabled?(:global_feature)
    end

    test "per user", %{viewer: viewer} do
      FeatureFlag.enable(:user_feature, for_actor: viewer)
      assert FeatureFlag.enabled?(:user_feature, for: viewer)

      FeatureFlag.clear(:user_feature, for_actor: viewer)
      refute FeatureFlag.enabled?(:user_feature, for: viewer)
    end

    test "per role", %{admin: admin} do
      FeatureFlag.enable(:role_feature, for_group: :admin)
      assert FeatureFlag.enabled?(:role_feature, for: admin)

      FeatureFlag.clear(:role_feature, for_group: :admin)
      refute FeatureFlag.enabled?(:role_feature, for: admin)
    end
  end
end
