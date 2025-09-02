defmodule PremiereEcoute.Discography.Playlist do
  @moduledoc false

  use PremiereEcouteCore.Aggregate,
    root: [:tracks],
    identity: [:playlist_id],
    json: [:id, :title, :cover_url]

  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer(),
          provider: :spotify | :deezer,
          playlist_id: String.t(),
          owner_id: String.t() | nil,
          owner_name: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          url: String.t() | nil,
          cover_url: String.t() | nil,
          public: boolean(),
          tracks: [Track.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "playlists" do
    field :provider, Ecto.Enum, values: [:spotify, :deezer]
    field :playlist_id, :string

    field :owner_id, :string
    field :owner_name, :string

    field :title, :string
    field :description, :string
    field :url, :string
    field :cover_url, :string
    field :public, :boolean, default: true

    has_many :tracks, Track, foreign_key: :playlist_id, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:provider, :playlist_id, :owner_id, :owner_name, :title, :description, :url, :cover_url, :public])
    |> validate_required([:provider, :playlist_id, :owner_id, :owner_name, :title])
    |> validate_inclusion(:provider, [:spotify, :deezer])
    |> unique_constraint([:playlist_id, :provider])
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: false)
  end

  def create(%__MODULE__{} = playlist) do
    playlist
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end

  def url(%{provider: :spotify, playlist_id: id}), do: "https://open.spotify.com/playlist/#{id}"
  def url(%{provider: :deezer, playlist_id: id}), do: "https://www.deezer.com/playlist/#{id}"
end
