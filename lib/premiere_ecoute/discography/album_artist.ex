defmodule PremiereEcoute.Discography.AlbumArtist do
  @moduledoc false

  use Ecto.Schema

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist

  @type t :: %__MODULE__{album_id: integer() | nil, artist_id: integer() | nil}

  @primary_key false
  schema "album_artists" do
    belongs_to :album, Album
    belongs_to :artist, Artist
  end
end
