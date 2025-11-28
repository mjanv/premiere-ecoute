defmodule PremiereEcouteWeb.Accounts.UserSessionController do
  @moduledoc """
  User session management controller.

  Handles user login via magic link or email/password, session creation and destruction, password updates with sudo mode protection, and automatic disconnection of expired sessions.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Accounts
  alias PremiereEcouteWeb.UserAuth

  @doc """
  Creates user session via email/password or magic link authentication.

  Authenticates user credentials, validates magic links, disconnects expired sessions, and establishes new authenticated session with appropriate flash messages.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, user, tokens_to_disconnect} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  @doc """
  Updates user password with sudo mode protection.

  Requires sudo mode verification, updates password, invalidates all existing sessions including active LiveView connections, and re-authenticates user with new credentials.
  """
  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, _user, expired_tokens} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  @doc """
  Terminates user session and logs out.

  Clears session data, invalidates authentication tokens, and redirects to login page with logout confirmation message.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
