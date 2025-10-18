defmodule PremiereEcoute.Discography.LibraryPlaylist do
  @moduledoc false

  use PremiereEcouteCore.Aggregate,
    identity: [:provider, :playlist_id]

  import Ecto.Query
  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
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
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "library_playlists" do
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

  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:provider, :playlist_id, :title, :description, :url, :cover_url, :public, :track_count, :metadata, :user_id])
    |> validate_required([:provider, :playlist_id, :title, :url, :user_id])
    |> validate_inclusion(:provider, [:spotify, :deezer])
    |> unique_constraint([:user_id, :playlist_id, :provider])
    |> foreign_key_constraint(:user_id)
  end

  def create(%User{id: id}, attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, :user_id, id))
    |> Repo.insert()
  end

  def exists?(%User{id: id}, %__MODULE__{playlist_id: playlist_id, provider: provider}) do
    from(p in __MODULE__,
      where: p.user_id == ^id and p.playlist_id == ^playlist_id and p.provider == ^provider
    )
    |> Repo.exists?()
  end

  def all_for_user(%User{id: id}) do
    from(p in __MODULE__,
      where: p.user_id == ^id,
      order_by: [desc: p.updated_at]
    )
    |> Repo.all()
  end
end
