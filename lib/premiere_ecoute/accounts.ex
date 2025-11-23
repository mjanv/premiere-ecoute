defmodule PremiereEcoute.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias PremiereEcoute.Accounts.Services
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Accounts.User.OauthToken
  alias PremiereEcoute.Accounts.User.Token

  ## User
  defdelegate preload_user(user), to: User, as: :preload
  defdelegate get_user_by_email(email), to: User
  defdelegate get_user_by_email_and_password(email, password), to: User
  defdelegate get_user_by_twitch_id(twitch_user_id), to: User
  defdelegate get_user!(id), to: User, as: :get
  defdelegate sudo_mode?(user, minutes \\ -20), to: User
  defdelegate create_user(attrs), to: User, as: :create
  defdelegate update_user_email(user, token), to: User
  defdelegate change_user_password(user, attrs \\ %{}, opts \\ []), to: User, as: :password_changeset
  defdelegate update_user_password(user, attrs), to: User
  defdelegate update_user_role(user, role), to: User
  defdelegate download_associated_data(scope), to: Services.AccountCompliance
  defdelegate delete_account(scope), to: Services.AccountCompliance

  def admins, do: User.all(where: [role: :admin])
  def bots, do: User.all(where: [role: :bot])
  def streamers, do: User.all(where: [role: :streamer])

  ## User Token
  defdelegate generate_user_session_token(user), to: Token
  defdelegate get_user_by_session_token(token), to: Token
  defdelegate get_user_by_magic_link_token(token), to: Token
  defdelegate login_user_by_magic_link(token), to: Token
  defdelegate deliver_user_update_email_instructions(user, email, fun), to: Token
  defdelegate deliver_login_instructions(user, fun), to: Token
  defdelegate delete_user_session_token(token), to: Token

  ## Oauth Token
  defdelegate delete_all_oauth_tokens(user), to: OauthToken, as: :delete_all_tokens

  ## Follow
  defdelegate follow(user, streamer, opts \\ %{}), to: Follow
  defdelegate unfollow(user, streamer), to: Follow
  defdelegate discover_follows(user), to: Follow
  defdelegate follow_streamer(scope, streamer), to: Services.AccountFollow
  defdelegate follow_streamers(scope), to: Services.AccountFollow
  defdelegate maybe_renew_token(scope, provider), to: Services.TokenRenewal
end
