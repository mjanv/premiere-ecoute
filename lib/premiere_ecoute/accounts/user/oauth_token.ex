defmodule PremiereEcoute.Accounts.User.OauthToken do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Repo

  alias PremiereEcoute.Accounts.User

  schema "users_oauth_tokens" do
    field :provider, Ecto.Enum, values: [:twitch, :spotify]
    field :user_id, :string
    field :username, :string
    field :access_token, PremiereEcoute.Repo.Encrypted, redact: true
    field :refresh_token, PremiereEcoute.Repo.Encrypted, redact: true
    field :expires_at, :utc_datetime

    belongs_to :parent, PremiereEcoute.Accounts.User

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
    |> validate_required([:access_token, :refresh_token, :expires_at])
  end

  def create(%User{id: id} = user, provider, %{expires_in: expires_in} = attrs) do
    %__MODULE__{}
    |> changeset(
      Map.merge(attrs, %{parent_id: id, provider: provider, expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)})
    )
    |> Repo.insert()
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end

  def refresh(%User{id: id} = user, provider, attrs) do
    case Repo.get_by(__MODULE__, parent_id: id, provider: provider) do
      nil -> {:error, nil}
      token -> Repo.update(refresh_changeset(token, attrs))
    end
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end

  def disconnect(%User{id: id} = user, provider) do
    case Repo.get_by(__MODULE__, parent_id: id, provider: provider) do
      nil -> {:error, nil}
      token -> Repo.delete(token)
    end
    |> then(fn {status, _token} -> {status, User.preload(user)} end)
  end
end
