defmodule PremiereEcoute.Accounts.User.LibraryPlaylist do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Accounts.User

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
    |> cast(attrs, [:provider, :playlist_id, :title, :description, :url, :cover_url, :public, :track_count, :metadata])
    |> validate_required([:provider, :playlist_id, :title, :url])
    |> validate_inclusion(:provider, [:spotify, :deezer])
    |> unique_constraint([:playlist_id, :provider])
  end
end
