defmodule PremiereEcoute.Festivals.Festival do
  @moduledoc """
  Festival embedded schema.

  Represents music festival with name, location, dates, and lineup concerts with associated Spotify tracks.
  """

  use Ecto.Schema

  @type t :: %__MODULE__{
          name: String.t() | nil,
          location: String.t() | nil,
          country: String.t() | nil,
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          concerts: [PremiereEcoute.Festivals.Festival.Concert.t()]
        }

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:location, :string)
    field(:country, :string)
    field(:start_date, :date)
    field(:end_date, :date)

    embeds_many :concerts, Concert, primary_key: false do
      @moduledoc """
      Concert embedded schema.

      Represents a festival concert with artist name, performance date, and associated track information.
      """

      @type t :: %__MODULE__{
              artist: String.t() | nil,
              date: Date.t() | nil,
              track: PremiereEcoute.Festivals.Festival.Concert.Track.t() | nil
            }

      field(:artist, :string)
      field(:date, :date)

      embeds_one :track, Track, primary_key: false do
        @moduledoc """
        Track embedded schema.

        Represents a music track with provider information (Spotify), track ID, and track name.
        """

        @type t :: %__MODULE__{
                provider: String.t() | nil,
                track_id: String.t() | nil,
                name: String.t() | nil
              }

        field(:provider, :string)
        field(:track_id, :string)
        field(:name, :string)
      end
    end
  end
end
