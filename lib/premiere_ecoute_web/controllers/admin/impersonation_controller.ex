defmodule PremiereEcouteWeb.Admin.ImpersonationController do
  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Accounts
  alias PremiereEcouteWeb.UserAuth

  @doc """
  Starts impersonation of a target user.
  Only admins can impersonate other users.
  """
  def create(conn, %{"user_id" => user_id}) do
    current_scope = conn.assigns.current_scope

    cond do
      # Check if user is authenticated
      is_nil(current_scope) or is_nil(current_scope.user) ->
        conn
        |> put_flash(:error, "You must be logged in to access this feature")
        |> redirect(to: ~p"/")

      # Check if user is admin
      current_scope.user.role != :admin ->
        conn
        |> put_flash(:error, "Only administrators can impersonate users")
        |> redirect(to: ~p"/")

      # Check if already impersonating or trying to impersonate themselves
      current_scope.impersonating? ->
        conn
        |> put_flash(:error, "You are already impersonating a user. Please switch back first")
        |> redirect(to: ~p"/admin")

      # Check if trying to impersonate themselves
      user_id == current_scope.user.id ->
        conn
        |> put_flash(:error, "You cannot impersonate yourself")
        |> redirect(to: ~p"/admin")

      # Proceed with impersonation
      true ->
        case Accounts.get_user!(user_id) do
          nil ->
            conn
            |> put_flash(:error, "User not found")
            |> redirect(to: ~p"/admin/users")

          target_user ->
            # AIDEV-NOTE: Admin impersonation start - generates new session token for target user
            conn
            |> UserAuth.start_impersonation(current_scope.user, target_user)
            |> put_flash(:info, "Now impersonating #{target_user.twitch_username || target_user.email}")
            |> redirect(to: ~p"/")
        end
    end
  end

  @doc """
  Ends the current impersonation and returns to admin context.
  """
  def delete(conn, _params) do
    current_scope = conn.assigns.current_scope

    if current_scope && current_scope.impersonating? do
      # AIDEV-NOTE: Admin impersonation end - clears impersonated token from session
      conn
      |> UserAuth.end_impersonation()
      |> put_flash(:info, "Impersonation ended. You are now back to your admin account")
      |> redirect(to: ~p"/admin")
    else
      conn
      |> put_flash(:error, "You are not currently impersonating anyone")
      |> redirect(to: ~p"/admin")
    end
  end
end
