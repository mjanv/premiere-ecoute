defmodule PremiereEcoute.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PremiereEcoute.Accounts` context.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User.OauthToken
  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcoute.Repo

  def unique_user_id, do: "#{System.unique_integer([:positive])}"
  def unique_username, do: "username-#{System.unique_integer([:positive])}"
  def unique_user_email, do: "user-#{System.unique_integer([:positive])}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{email: unique_user_email()})
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    attrs
    |> valid_user_attributes()
    |> Accounts.create_user()
    |> then(fn {:ok, user} -> user end)
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, user, _expired_tokens} = Accounts.login_user_by_magic_link(token)

    {:ok, user} =
      OauthToken.create(
        user,
        :twitch,
        %{
          username: unique_username(),
          user_id: unique_user_id(),
          access_token: "access_token",
          refresh_token: "refresh_token",
          expires_in: 3600
        }
        |> Map.merge(Map.get(attrs, :twitch, %{}))
      )

    {:ok, user} =
      OauthToken.create(
        user,
        :spotify,
        %{
          username: unique_username(),
          user_id: unique_user_id(),
          access_token: "access_token",
          refresh_token: "refresh_token",
          expires_in: 3600
        }
        |> Map.merge(Map.get(attrs, :spotify, %{}))
      )

    user
  end

  def user_fixture2(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, user, _expired_tokens} = Accounts.login_user_by_magic_link(token)

    user
  end

  def user_scope_fixture, do: user_scope_fixture(user_fixture())
  def user_scope_fixture(user), do: Scope.for_user(user)

  def set_password(user) do
    {:ok, user, _expired_tokens} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    captured_email.text_body
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Repo.update_all(from(t in Token, where: t.token == ^token), set: [authenticated_at: authenticated_at])
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Token.build_email_token(user, "login")
    Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)
    Repo.update_all(from(ut in Token, where: ut.token == ^token), set: [inserted_at: dt, authenticated_at: dt])
  end
end
