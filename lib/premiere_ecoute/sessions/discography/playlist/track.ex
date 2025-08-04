defmodule PremiereEcoute.Sessions.Discography.Playlist.Track do
  @moduledoc false

  use PremiereEcoute.Core.Aggregate,
    json: [:spotify_id, :album_spotify_id, :user_spotify_id, :name, :artist, :duration_ms, :added_at]

  alias PremiereEcoute.Sessions.Discography.Playlist

  @type t :: %__MODULE__{
          id: integer() | nil,
          spotify_id: String.t() | nil,
          album_spotify_id: String.t() | nil,
          user_spotify_id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          duration_ms: integer() | nil,
          playlist_id: integer() | nil,
          playlist: entity(Playlist.t()),
          added_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "playlist_tracks" do
    field :spotify_id, :string
    field :album_spotify_id, :string
    field :user_spotify_id, :string
    field :name, :string
    field :artist, :string
    field :duration_ms, :integer
    field :added_at, :naive_datetime

    belongs_to :playlist, Playlist

    timestamps(type: :utc_datetime)
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [:spotify_id, :album_spotify_id, :user_spotify_id, :name, :artist, :duration_ms, :added_at])
    |> validate_required([:spotify_id, :album_spotify_id, :user_spotify_id, :name, :artist, :duration_ms, :added_at])
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
  end
end
