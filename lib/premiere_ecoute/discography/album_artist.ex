defmodule PremiereEcoute.Discography.AlbumArtist do
  @moduledoc false

  use Ecto.Schema

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist

  @primary_key false
  schema "album_artists" do
    belongs_to :album, Album
    belongs_to :artist, Artist
  end
end
