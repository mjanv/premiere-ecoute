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

  @doc """
  Generates unique user ID string for testing.

  Creates monotonically increasing positive integer as string to ensure unique test user identifiers.
  """
  @spec unique_user_id() :: String.t()
  def unique_user_id, do: "#{System.unique_integer([:positive])}"

  @doc """
  Generates unique username for testing.

  Creates username with monotonically increasing positive integer suffix to ensure unique test usernames.
  """
  @spec unique_username() :: String.t()
  def unique_username, do: "username-#{System.unique_integer([:positive])}"

  @doc """
  Generates unique email address for testing.

  Creates email with monotonically increasing positive integer to ensure unique test email addresses.
  """
  @spec unique_user_email() :: String.t()
  def unique_user_email, do: "user-#{System.unique_integer([:positive])}@example.com"

  @doc """
  Returns default valid password for test users.

  Provides static password string that meets validation requirements for all test fixtures.
  """
  @spec valid_user_password() :: String.t()
  def valid_user_password, do: "hello world!"

  @doc """
  Generates valid user attributes map with optional profile for testing.

  Merges provided attributes with default email and username, separating profile attributes into nested map if present.
  """
  @spec valid_user_attributes(map()) :: map()
  def valid_user_attributes(attrs \\ %{}) do
    {profile_attrs, user_attrs} = Map.pop(Map.new(attrs), :profile, %{})
    user_attrs = Enum.into(user_attrs, %{email: unique_user_email(), username: unique_username()})

    if profile_attrs == %{} do
      user_attrs
    else
      Map.put(user_attrs, :profile, profile_attrs)
    end
  end

  @doc """
  Creates unconfirmed user fixture in database for testing.

  Inserts user record with valid attributes merged from provided map, returning unconfirmed user struct without email verification.
  """
  @spec unconfirmed_user_fixture(map()) :: User.t()
  def unconfirmed_user_fixture(attrs \\ %{}) do
    Repo.insert!(User.changeset(struct(User), valid_user_attributes(attrs)))
  end

  @doc """
  Creates confirmed user fixture with OAuth tokens for testing.

  Creates unconfirmed user, authenticates via magic link, generates OAuth tokens for specified providers (twitch/spotify), and returns user merged with token maps.
  """
  @spec user_fixture(map()) :: User.t()
  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)
    token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

    {:ok, user, _expired_tokens} = Accounts.login_user_by_magic_link(token)

    tokens = oauth_tokens_fixture(user, Map.take(attrs, [:twitch, :spotify]))

    Map.merge(user, tokens)
  end

  @doc """
  Creates OAuth token fixtures for user and providers in database.

  Inserts OAuth tokens for specified providers with custom or default attributes, returning map of provider atoms to token structs.
  """
  @spec oauth_tokens_fixture(User.t(), map()) :: map()
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

  @doc """
  Creates scope fixture for user with provider-specific permissions.

  Generates scope struct containing user ID and OAuth scopes from linked provider tokens for testing authorization.
  """
  @spec user_scope_fixture(User.t()) :: Scope.t()
  def user_scope_fixture(user), do: Scope.for_user(user)

  @doc """
  Sets valid password on user fixture for authentication testing.

  Updates user with default valid password via Accounts context, returning updated user struct for password-based login tests.
  """
  @spec set_password(User.t()) :: User.t()
  def set_password(user) do
    {:ok, user, _} = Accounts.update_user_password(user, %{password: valid_user_password()})
    user
  end

  @doc """
  Extracts authentication token from email notification function.

  Executes email delivery function with token placeholder, capturing and extracting token string from email text body for test assertions.
  """
  @spec extract_user_token(function()) :: String.t()
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    captured_email.text_body
  end

  @doc """
  Overrides authenticated_at timestamp on user token for testing.

  Updates token record with custom authenticated_at datetime to test time-sensitive authentication scenarios like token expiry.
  """
  @spec override_token_authenticated_at(String.t(), DateTime.t()) :: {integer(), nil | [term()]}
  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Repo.update_all(from(t in Token, where: t.token == ^token), set: [authenticated_at: authenticated_at])
  end

  @doc """
  Generates magic link token for user authentication testing.

  Creates and persists login token for user, returning tuple with encoded token string and raw token hash for test verification.
  """
  @spec generate_user_magic_link_token(User.t()) :: {String.t(), binary()}
  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Token.build_email_token(user, "login")
    Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  @doc """
  Offsets user token timestamps for time-based testing scenarios.

  Updates token's inserted_at and authenticated_at by adding specified amount in given time unit to test token expiration and validity periods.
  """
  @spec offset_user_token(binary(), integer(), System.time_unit()) :: {integer(), nil | [term()]}
  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)
    Repo.update_all(from(ut in Token, where: ut.token == ^token), set: [inserted_at: dt, authenticated_at: dt])
  end
end
