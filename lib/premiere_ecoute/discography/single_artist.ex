defmodule PremiereEcoute.Discography.SingleArtist do
  @moduledoc false

  use Ecto.Schema

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single

  @primary_key false
  schema "single_artists" do
    belongs_to :single, Single
    belongs_to :artist, Artist
  end
end
