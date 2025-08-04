defmodule PremiereEcoute.Accounts.User.LibraryPlaylist do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Accounts.User

  schema "user_library_playlists" do
    field :provider, Ecto.Enum, values: [:spotify]
    field :playlist_id, :string
    field :url, :string

    field :title, :string
    field :description, :string
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
    |> cast(attrs, [:provider, :playlist_id, :title, :description, :cover_url, :public, :url, :track_count, :metadata])
    |> validate_required([:provider, :playlist_id, :url, :title])
    |> validate_inclusion(:provider, [:spotify])
  end
end
