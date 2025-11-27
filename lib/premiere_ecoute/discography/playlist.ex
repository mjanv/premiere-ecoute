defmodule PremiereEcoute.Discography.Playlist do
  @moduledoc """
  Playlist aggregate.

  Stores playlists from Spotify and Deezer with owner information, tracks, and metadata for music catalog management.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:tracks],
    identity: [:playlist_id],
    json: [:id, :title, :cover_url]

  alias PremiereEcoute.Apis.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
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
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
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

  @doc "Playlist changeset."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:provider, :playlist_id, :owner_id, :owner_name, :title, :description, :url, :cover_url, :public])
    |> validate_required([:provider, :playlist_id, :owner_id, :owner_name, :title])
    |> validate_inclusion(:provider, [:spotify, :deezer])
    |> unique_constraint([:playlist_id, :provider])
    |> cast_assoc(:tracks, with: &Track.changeset/2, required: false)
  end

  @doc """
  Creates a playlist with tracks.

  Converts playlist and tracks from structs to maps and inserts with associated tracks in a single transaction.
  """
  @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{} = playlist) do
    playlist
    |> Map.from_struct()
    |> Map.update!(:tracks, fn tracks -> Enum.map(tracks, &Map.from_struct/1) end)
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end

  @doc """
  Adds a track to a playlist.

  Parses track data from Spotify API response and appends to playlist's tracks. Updates playlist in database with new track.
  """
  @spec add_track_to_playlist(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def add_track_to_playlist(%__MODULE__{} = playlist, %{"item" => track}) do
    track = %{
      provider: :spotify,
      track_id: track["id"],
      album_id: track["album"]["id"],
      user_id: playlist.owner_id,
      name: track["name"],
      artist: Parser.parse_primary_artist(track["artists"]),
      duration_ms: track["duration_ms"],
      added_at: NaiveDateTime.utc_now(),
      release_date: ~D[1900-01-01]
    }

    playlist
    |> cast(%{tracks: Enum.map(playlist.tracks, &Map.from_struct/1) ++ [track]}, [])
    |> cast_assoc(:tracks)
    |> Repo.update()
  end

  @doc """
  Generates the external URL for a playlist.

  Returns the appropriate URL based on provider (Spotify or Deezer) and playlist ID.
  """
  @spec url(t()) :: String.t()
  def url(%{provider: :spotify, playlist_id: id}), do: "https://open.spotify.com/playlist/#{id}"
  def url(%{provider: :deezer, playlist_id: id}), do: "https://www.deezer.com/playlist/#{id}"
end
