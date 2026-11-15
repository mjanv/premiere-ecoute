defmodule PremiereEcoute.Wrapped.Listen do
  @moduledoc """
  Something a viewer voted on during a year, with the result of their votes.

  `entity` is the domain object itself: an album, a single, or a track of an album (with its album loaded). `result` is what the votes say about it. A viewer's year is a flat list of listens of the three kinds. Anything already known by the entity (name, cover, duration...) is read from it when needed, never copied.
  """

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single

  defmodule Result do
    @moduledoc """
    Result of the votes of a viewer on one entity, over every session it was played in.

    Scores are on /10 and `nil` for sessions with a non-numeric scale. `streamers` names the streamer of each session, one entry per session.
    """

    @enforce_keys [:voted_at]
    defstruct [:voted_at, :score, :chat_score, streamers: []]

    @type t :: %__MODULE__{
            voted_at: DateTime.t(),
            score: float() | nil,
            chat_score: float() | nil,
            streamers: [String.t()]
          }
  end

  @enforce_keys [:entity, :result]
  defstruct [:entity, :result]

  @type t :: %__MODULE__{
          entity: Album.t() | Single.t() | Album.Track.t(),
          result: Result.t()
        }

  @doc "Keeps the album listens."
  @spec albums([t()]) :: [t()]
  def albums(listens), do: Enum.filter(listens, &match?(%__MODULE__{entity: %Album{}}, &1))

  @doc "Keeps the single listens."
  @spec singles([t()]) :: [t()]
  def singles(listens), do: Enum.filter(listens, &match?(%__MODULE__{entity: %Single{}}, &1))

  @doc "Keeps the track listens."
  @spec tracks([t()]) :: [t()]
  def tracks(listens), do: Enum.filter(listens, &match?(%__MODULE__{entity: %Album.Track{}}, &1))

  @doc "Name of the entity."
  @spec name(t()) :: String.t() | nil
  def name(%__MODULE__{entity: entity}), do: entity.name

  @doc "Name of the first artist of an album or a single; a track has the artist of its album."
  @spec artist(t()) :: String.t() | nil
  def artist(%__MODULE__{entity: %Album.Track{album: %Album{artists: [%{name: name} | _]}}}), do: name
  def artist(%__MODULE__{entity: %{artists: [%{name: name} | _]}}), do: name
  def artist(%__MODULE__{}), do: nil

  @doc "Cover of an album or a single; a track has the cover of its album."
  @spec cover_url(t()) :: String.t() | nil
  def cover_url(%__MODULE__{entity: %Album.Track{album: %Album{cover_url: cover_url}}}), do: cover_url
  def cover_url(%__MODULE__{entity: %Album.Track{}}), do: nil
  def cover_url(%__MODULE__{entity: entity}), do: entity.cover_url

  @doc "Name of the track that opens the entity: the first track of an album, the single or the track itself."
  @spec opening_track(t()) :: String.t() | nil
  def opening_track(%__MODULE__{entity: %Album{tracks: [_ | _] = tracks}}), do: Enum.min_by(tracks, & &1.track_number).name
  def opening_track(%__MODULE__{entity: %Album{}}), do: nil
  def opening_track(%__MODULE__{entity: entity}), do: entity.name

  @doc "Number of sessions the entity was voted on in."
  @spec sessions(t()) :: integer()
  def sessions(%__MODULE__{result: %Result{streamers: streamers}}), do: length(streamers)

  @doc "Time spent listening: the duration of the entity for each session it was played in."
  @spec duration_ms(t()) :: integer()
  def duration_ms(%__MODULE__{entity: %Album{} = album} = listen), do: Album.total_duration(album) * sessions(listen)
  def duration_ms(%__MODULE__{entity: entity} = listen), do: (entity.duration_ms || 0) * sessions(listen)
end
