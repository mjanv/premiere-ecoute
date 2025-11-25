defmodule PremiereEcoute.Discography.Playlist.Track do
  @moduledoc """
  Playlist track aggregate.

  Stores individual tracks within playlists including track metadata, artist, duration, and when the track was added to the playlist.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:provider, :track_id, :album_id, :user_id, :name, :artist, :release_date, :duration_ms, :added_at]

  alias PremiereEcoute.Discography.Playlist

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: :spotify | :deezer,
          track_id: String.t(),
          album_id: String.t() | nil,
          user_id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          release_date: Date.t() | nil,
          duration_ms: integer() | nil,
          added_at: NaiveDateTime.t() | nil,
          playlist_id: integer() | nil,
          playlist: Playlist.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "playlist_tracks" do
    field :provider, Ecto.Enum, values: [:spotify, :deezer]
    field :track_id, :string
    field :album_id, :string
    field :user_id, :string
    field :name, :string
    field :artist, :string
    field :release_date, :date
    field :duration_ms, :integer
    field :added_at, :naive_datetime

    belongs_to :playlist, Playlist

    timestamps(type: :utc_datetime)
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [:provider, :track_id, :album_id, :user_id, :name, :artist, :release_date, :duration_ms, :added_at])
    |> validate_required([:provider, :track_id, :album_id, :user_id, :name, :artist, :duration_ms, :added_at])
    |> validate_inclusion(:provider, [:spotify, :deezer])
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> unique_constraint([:provider, :playlist_id, :track_id], name: :playlist_tracks_playlist_id_track_id_provider_index)
  end

  def url(%{provider: :spotify, track_id: id}), do: "https://open.spotify.com/track/#{id}"
  def url(%{provider: :deezer, track_id: id}), do: "https://www.deezer.com/track/#{id}"
end
