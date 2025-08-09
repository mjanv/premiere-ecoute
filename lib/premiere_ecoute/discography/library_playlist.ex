defmodule PremiereEcoute.Accounts.User.LibraryPlaylist do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer(),
          provider: :spotify | :deezer,
          playlist_id: String.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          url: String.t() | nil,
          cover_url: String.t() | nil,
          public: boolean(),
          track_count: integer(),
          metadata: map() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "user_library_playlists" do
    field :provider, Ecto.Enum, values: [:spotify, :deezer]
    field :playlist_id, :string

    field :title, :string
    field :description, :string
    field :url, :string
    field :cover_url, :string
    field :public, :boolean, default: true
    field :track_count, :integer

    field :metadata, :map

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:provider, :playlist_id, :title, :description, :url, :cover_url, :public, :track_count, :metadata, :user_id])
    |> validate_required([:provider, :playlist_id, :title, :url, :user_id])
    |> validate_inclusion(:provider, [:spotify, :deezer])
    |> unique_constraint([:playlist_id, :provider])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a new library playlist for a user.
  """
  def create(user, attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc """
  Gets all library playlists for a user.
  """
  def get_user_playlists(user) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Deletes a library playlist for a user.
  """
  def delete_playlist(user, playlist_id, provider) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id and p.playlist_id == ^playlist_id and p.provider == ^provider
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      playlist -> Repo.delete(playlist)
    end
  end

  @doc """
  Checks if a playlist is already in the user's library.
  """
  def exists?(user, playlist_id, provider) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id and p.playlist_id == ^playlist_id and p.provider == ^provider
    )
    |> Repo.exists?()
  end
end
