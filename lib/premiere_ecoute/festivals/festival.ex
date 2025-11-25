defmodule PremiereEcoute.Festivals.Festival do
  @moduledoc """
  Festival embedded schema.

  Represents music festival with name, location, dates, and lineup concerts with associated Spotify tracks.
  """

  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:location, :string)
    field(:country, :string)
    field(:start_date, :date)
    field(:end_date, :date)

    embeds_many :concerts, Concert, primary_key: false do
      field(:artist, :string)
      field(:date, :date)

      embeds_one :track, Track, primary_key: false do
        field(:provider, :string)
        field(:track_id, :string)
        field(:name, :string)
      end
    end
  end
end
