defmodule PremiereEcoute.Sessions.Discography.Playlist do
  @moduledoc false

  use PremiereEcoute.Core.Aggregate,
    root: [:tracks],
    identity: [:spotify_id],
    json: [:id, :name, :cover_url]

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  @type t :: %__MODULE__{
          id: integer() | nil,
          spotify_id: String.t() | nil,
          name: String.t() | nil,
          cover_url: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "playlists" do
    field :name, :string
    field :owner_name, :string
    field :spotify_id, :string
    field :spotify_owner_id, :string
    field :cover_url, :string

    has_many :tracks, Track, foreign_key: :playlist_id, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:spotify_id, :name, :spotify_owner_id, :owner_name, :cover_url])
    |> validate_required([:spotify_id, :name, :spotify_owner_id, :owner_name, :cover_url])
    |> unique_constraint(:spotify_id)
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: true)
  end

  def create(%__MODULE__{} = playlist) do
    playlist
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end
end
