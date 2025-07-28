defmodule PremiereEcoute.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Accounts.UserToken

  ## User
  defdelegate get_user_by_email(email), to: User
  defdelegate get_user_by_email_and_password(email, password), to: User
  defdelegate get_user!(id), to: User
  defdelegate sudo_mode?(user, minutes \\ -20), to: User
  defdelegate create_user(attrs), to: User, as: :create
  defdelegate update_user_email(user, token), to: User
  defdelegate change_user_password(user, attrs \\ %{}, opts \\ []), to: User, as: :password_changeset
  defdelegate update_user_password(user, attrs), to: User
  defdelegate update_user_role(user, role), to: User

  ## User Token
  defdelegate generate_user_session_token(user), to: UserToken
  defdelegate get_user_by_session_token(token), to: UserToken
  defdelegate get_user_by_magic_link_token(token), to: UserToken
  defdelegate login_user_by_magic_link(token), to: UserToken
  defdelegate deliver_user_update_email_instructions(user, email, fun), to: UserToken
  defdelegate deliver_login_instructions(user, fun), to: UserToken
  defdelegate delete_user_session_token(token), to: UserToken

  ## Follow
  defdelegate follow(user, streamer), to: Follow
  defdelegate unfollow(user, streamer), to: Follow
end
