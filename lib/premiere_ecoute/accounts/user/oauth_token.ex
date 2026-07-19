defmodule PremiereEcoute.Accounts.User.OauthToken do
  @moduledoc """
  User OAuth tokens for external providers.

  Stores encrypted access and refresh tokens for Twitch and Spotify providers, handles token creation/refresh/disconnection, and publishes AccountAssociated events when tokens are created.
  """

  use PremiereEcouteCore.Aggregate.Entity,
    json: [:user_id, :username]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.AccountAssociated

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: :twitch | :spotify,
          user_id: String.t(),
          username: String.t(),
          access_token: binary() | nil,
          refresh_token: binary() | nil,
          expires_at: DateTime.t() | nil,
          parent_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "user_oauth_tokens" do
    field :provider, Ecto.Enum, values: [:twitch, :spotify]
    field :user_id, :string
    field :username, :string
    field :access_token, PremiereEcoute.Repo.EncryptedField, redact: true
    field :refresh_token, PremiereEcoute.Repo.EncryptedField, redact: true
    field :expires_at, :utc_datetime

    belongs_to :parent, User

    timestamps()
  end

  @doc "OAuth token changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:provider, :user_id, :username, :access_token, :refresh_token, :expires_at, :parent_id])
    |> validate_required([:provider, :user_id, :username, :access_token, :refresh_token, :expires_at, :parent_id])
    |> validate_inclusion(:provider, [:twitch, :spotify])
    |> unique_constraint([:user_id, :provider], name: :unique_user_provider_tokens)
  end

  @doc "OAuth token refresh changeset."
  @spec refresh_changeset(t(), map()) :: Ecto.Changeset.t()
  def refresh_changeset(user, attrs) do
    user
    |> cast(attrs, [:access_token, :refresh_token, :expires_at])
    |> validate_required([])
  end

  @doc """
  Creates or updates OAuth tokens for a user and provider.

  Checks if tokens already exist for the provider and user_id combination. If found, updates the existing record, otherwise creates a new one. Calculates expiration timestamp from expires_in value.

  Publishes an AccountAssociated event upon success.
  """
  @spec create(User.t(), atom(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create(%User{id: id} = user, provider, %{user_id: user_id, expires_in: expires_in} = attrs) do
    case get_by(provider: provider, user_id: user_id) do
      nil -> %__MODULE__{}
      token -> token
    end
    |> changeset(
      Map.merge(attrs, %{parent_id: id, provider: provider, expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)})
    )
    |> Repo.insert_or_update()
    |> Store.ok("user", fn token -> %AccountAssociated{id: token.parent_id, provider: token.provider, user_id: token.user_id} end)
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end

  @doc """
  Refreshes OAuth tokens for a user and provider.

  Looks up existing tokens by parent_id and provider, then updates them with new credentials and expiration. Returns error if no tokens exist for the provider.
  """
  @spec refresh(User.t(), atom(), map()) :: {:ok, User.t()} | {:error, nil | Ecto.Changeset.t()}
  def refresh(%User{id: id} = user, provider, %{expires_in: expires_in} = attrs) do
    case Repo.get_by(__MODULE__, parent_id: id, provider: provider) do
      nil ->
        {:error, nil}

      token ->
        Repo.update(
          refresh_changeset(token, Map.merge(attrs, %{expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)}))
        )
    end
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end

  @doc """
  Refreshes OAuth tokens for a user and provider under a row lock, serializing
  concurrent refresh attempts for the same user/provider.

  Locks the token row with `SELECT ... FOR UPDATE`, then re-checks expiry (via
  `expired_fun`) against the locked row before calling `renew_fun`. This prevents
  a race where two concurrent callers both read the same soon-to-be-rotated
  refresh token: the loser would otherwise call the provider with a token the
  winner already invalidated, receive `invalid_grant`, and disconnect an
  otherwise-healthy account. If another caller already refreshed the token while
  this one waited for the lock, `renew_fun` is skipped entirely and the
  now-current token is returned.

  `expired_fun` is a `expires_at -> boolean()` predicate (normally
  `TokenRenewal.token_expired?/1`) and `renew_fun` is a
  `refresh_token -> {:ok, map()} | {:error, term()}` function (normally
  `&provider_api.renew_token/1`) — both injected so this data-layer module
  doesn't depend on the service layer or on provider dispatch.

  Returns `{:ok, User.t()}` on success — either refreshed, already-fresh, or (if
  the refresh token was genuinely dead, confirmed by the locked re-check) with
  the provider disconnected. The disconnect itself runs after the locked
  transaction commits, not inside it — safe because `invalid_grant` means the
  token was already unusable, so no concurrent writer can race a *successful*
  refresh against it in that window.
  Returns `{:error, nil}` if no token row exists, or `{:error, reason}` for any
  other provider failure (token left untouched).
  """
  @spec refresh_locked(
          User.t(),
          atom(),
          (DateTime.t() | nil -> boolean()),
          (String.t() -> {:ok, map()} | {:error, term()})
        ) :: {:ok, User.t()} | {:error, nil | term()}
  def refresh_locked(%User{id: id} = user, provider, expired_fun, renew_fun)
      when is_function(expired_fun, 1) and is_function(renew_fun, 1) do
    Repo.transaction(fn ->
      from(t in __MODULE__, where: t.parent_id == ^id and t.provider == ^provider, lock: "FOR UPDATE")
      |> Repo.one()
      |> case do
        nil ->
          {:error, nil}

        %__MODULE__{expires_at: expires_at} = token ->
          if expired_fun.(expires_at) do
            renew_locked_token(token, renew_fun)
          else
            {:ok, token}
          end
      end
    end)
    |> then(fn {:ok, result} -> result end)
    |> case do
      {:ok, _token} -> {:ok, User.preload(user)}
      {:error, :invalid_grant} -> disconnect(user, provider)
      {:error, reason} -> {:error, reason}
    end
  end

  defp renew_locked_token(token, renew_fun) do
    case renew_fun.(token.refresh_token) do
      {:ok, %{expires_in: expires_in} = attrs} ->
        Repo.update(
          refresh_changeset(token, Map.merge(attrs, %{expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)}))
        )

      {:error, :invalid_grant} = error ->
        error

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Disconnects a provider by deleting its OAuth tokens.

  Removes the OAuth token record for the specified provider. Returns success even if no tokens exist for the provider.
  """
  @spec disconnect(User.t(), atom()) :: {:ok, User.t() | nil}
  def disconnect(%User{id: id} = user, provider) do
    case Repo.get_by(__MODULE__, parent_id: id, provider: provider) do
      nil -> {:ok, nil}
      token -> Repo.delete(token)
    end
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end

  @doc """
  Deletes all OAuth tokens for a user.

  Removes all provider token records associated with the user. Used for cleanup operations like account deletion.
  """
  @spec delete_all_tokens(User.t()) :: {:ok, User.t()}
  def delete_all_tokens(%User{id: id} = user) do
    from(t in __MODULE__, where: t.parent_id == ^id)
    |> Repo.delete_all()
    |> then(fn _ -> {:ok, User.preload(user)} end)
  end
end
