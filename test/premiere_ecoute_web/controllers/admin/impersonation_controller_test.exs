defmodule PremiereEcouteWeb.Admin.ImpersonationControllerTest do
  use PremiereEcouteWeb.ConnCase

  setup do
    # Create admin user
    admin = user_fixture(%{role: :admin})
    # Create target user to impersonate
    target_user = user_fixture(%{role: :viewer, twitch: %{username: "test_user"}})

    {:ok, admin: admin, target_user: target_user}
  end

  describe "create/2" do
    test "admin can start impersonation", %{conn: conn, admin: admin, target_user: target_user} do
      conn = log_in_user(conn, admin)

      conn = post(conn, ~p"/admin/impersonation", %{user_id: target_user.id})

      # Should redirect to homepage
      assert redirected_to(conn) == ~p"/"
      # Should have flash message
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Now impersonating test_user"
      # Should have impersonated token in session
      assert get_session(conn, :impersonated_token)
    end

    test "non-admin cannot start impersonation", %{conn: conn, target_user: target_user} do
      viewer = user_fixture(%{role: :viewer})
      conn = log_in_user(conn, viewer)

      conn = post(conn, ~p"/admin/impersonation", %{user_id: target_user.id})

      # Should redirect to homepage
      assert redirected_to(conn) == ~p"/"
      # Should have error message
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Only administrators can impersonate users"
      # Should not have impersonated token in session
      refute get_session(conn, :impersonated_token)
    end

    test "admin cannot impersonate themselves", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)

      conn = post(conn, ~p"/admin/impersonation", %{user_id: admin.id})

      # Should redirect to admin
      assert redirected_to(conn) == ~p"/admin"
      # Should have error message
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You cannot impersonate yourself"
    end

    test "admin cannot impersonate non-existent user", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)

      # Use a fake integer ID that doesn't exist
      fake_id = 99_999
      conn = post(conn, ~p"/admin/impersonation", %{user_id: fake_id})

      # Should redirect to admin users
      assert redirected_to(conn) == ~p"/admin/users"
      # Should have error message (could be "User not found" or "Invalid user ID")
      flash_error = Phoenix.Flash.get(conn.assigns.flash, :error)
      assert flash_error =~ "User not found" or flash_error =~ "Invalid user ID"
    end
  end

  describe "delete/2" do
    test "can end impersonation", %{conn: conn, admin: admin, target_user: target_user} do
      # Start impersonation first
      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/admin/impersonation", %{user_id: target_user.id})

      # Verify impersonation is active
      assert get_session(conn, :impersonated_token)

      # End impersonation
      conn = delete(conn, ~p"/admin/impersonation")

      # Should redirect to admin
      assert redirected_to(conn) == ~p"/admin"
      # Should have success message
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Impersonation ended"
      # Should not have impersonated token in session
      refute get_session(conn, :impersonated_token)
    end

    test "cannot end impersonation when not impersonating", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)

      conn = delete(conn, ~p"/admin/impersonation")

      # Should redirect to admin
      assert redirected_to(conn) == ~p"/admin"
      # Should have error message
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are not currently impersonating anyone"
    end
  end
end
