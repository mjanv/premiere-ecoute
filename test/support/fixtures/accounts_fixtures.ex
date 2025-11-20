defmodule PremiereEcoute.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PremiereEcoute.Accounts` context.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.OauthToken
  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcoute.Repo

  def unique_user_id, do: "#{System.unique_integer([:positive])}"
  def unique_username, do: "username-#{System.unique_integer([:positive])}"
  def unique_user_email, do: "user-#{System.unique_integer([:positive])}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    # AIDEV-NOTE: Extract profile separately to handle it via changeset. Convert keyword lists to maps first.
    attrs_map = Map.new(attrs)
    {profile_attrs, user_attrs} = Map.pop(attrs_map, :profile, %{})
    user_attrs = Enum.into(user_attrs, %{email: unique_user_email(), username: unique_username()})

    if profile_attrs == %{} do
      user_attrs
    else
      Map.put(user_attrs, :profile, profile_attrs)
    end
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    Repo.insert!(User.changeset(struct(User), valid_user_attributes(attrs)))
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)
    token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

    {:ok, user, _expired_tokens} = Accounts.login_user_by_magic_link(token)

    tokens = oauth_tokens_fixture(user, Map.take(attrs, [:twitch, :spotify]))

    Map.merge(user, tokens)
  end

  def oauth_tokens_fixture(user, provider_attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    now2 = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    tokens_data =
      for {provider, attrs} <- provider_attrs do
        %{
          provider: provider,
          user_id: Map.get(attrs, :user_id, unique_user_id()),
          username: Map.get(attrs, :username, unique_username()),
          access_token: Map.get(attrs, :access_token, "access_token"),
          refresh_token: Map.get(attrs, :refresh_token, "refresh_token"),
          expires_at: DateTime.add(now, Map.get(attrs, :expires_in, 3600), :second),
          parent_id: user.id,
          inserted_at: now2,
          updated_at: now2
        }
      end

    {_, tokens} = Repo.insert_all(OauthToken, tokens_data, returning: true)

    for {provider, _} <- provider_attrs do
      {provider, Enum.find(tokens, &(&1.provider == provider))}
    end
    |> Enum.into(%{})
  end

  def user_scope_fixture(user), do: Scope.for_user(user)

  def set_password(user) do
    {:ok, user, _} = Accounts.update_user_password(user, %{password: valid_user_password()})
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
