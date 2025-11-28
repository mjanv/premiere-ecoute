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
