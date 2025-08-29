defmodule PremiereEcoute.Accounts.User.OauthToken do
  @moduledoc false

  use PremiereEcouteCore.Aggregate.Entity,
    no_json: [:parent]

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
    field :access_token, PremiereEcoute.Repo.Encrypted, redact: true
    field :refresh_token, PremiereEcoute.Repo.Encrypted, redact: true
    field :expires_at, :utc_datetime

    belongs_to :parent, User

    timestamps()
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:provider, :user_id, :username, :access_token, :refresh_token, :expires_at, :parent_id])
    |> validate_required([:provider, :user_id, :username, :access_token, :refresh_token, :expires_at, :parent_id])
    |> validate_inclusion(:provider, [:twitch, :spotify])
    |> unique_constraint([:user_id, :provider], name: :unique_user_provider_tokens)
  end

  def refresh_changeset(user, attrs) do
    user
    |> cast(attrs, [:access_token, :refresh_token, :expires_at])
    |> validate_required([])
  end

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

  def disconnect(%User{id: id} = user, provider) do
    case Repo.get_by(__MODULE__, parent_id: id, provider: provider) do
      nil -> {:ok, nil}
      token -> Repo.delete(token)
    end
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end

  def delete_all_tokens(%User{id: id} = user) do
    from(t in __MODULE__, where: t.parent_id == ^id)
    |> Repo.delete_all()
    |> then(fn _ -> {:ok, User.preload(user)} end)
  end
end
