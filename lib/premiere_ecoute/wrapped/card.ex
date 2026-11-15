defmodule PremiereEcoute.Wrapped.Card do
  @moduledoc """
  A screen of a Wrapped, and the behaviour of the modules that build one.

  A card module turns listens into one card, or `:skip` when there is too little to show. `type` names the screen, `data` holds what it shows, `appearance` what it is tinted from and `preview` the track played behind it.
  """

  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Listen

  defmodule Track do
    @moduledoc """
    Track played behind a card, named so that a 30 s preview can be looked up when the page opens.
    """

    @derive Jason.Encoder
    @enforce_keys [:name, :artist]
    defstruct [:name, :artist]

    @type t :: %__MODULE__{name: String.t(), artist: String.t()}
  end

  @derive Jason.Encoder
  @enforce_keys [:type, :appearance]
  defstruct [:type, :appearance, :preview, data: %{}]

  @type t :: %__MODULE__{
          type: atom(),
          appearance: Appearance.t(),
          preview: Track.t() | nil,
          data: map()
        }

  @type album :: %{name: String.t(), artist: String.t() | nil, cover_url: String.t() | nil}

  @callback compute([Listen.t()]) :: t() | :skip

  @doc "Appearance of a card tinted from the cover of a listen, or from a cover URL."
  @spec appearance(Listen.t() | String.t() | nil) :: Appearance.t()
  def appearance(%Listen{} = listen), do: %Appearance{cover_url: Listen.cover_url(listen)}
  def appearance(cover_url), do: %Appearance{cover_url: cover_url}

  @doc "Keeps what a card shows of an album or a single."
  @spec album(Listen.t()) :: album()
  def album(%Listen{} = listen),
    do: %{name: Listen.name(listen), artist: Listen.artist(listen), cover_url: Listen.cover_url(listen)}

  @doc "Keeps what a card shows of an album or a single, with the viewer's score."
  @spec scored(Listen.t()) :: map()
  def scored(%Listen{} = listen), do: listen |> album() |> Map.put(:score, listen.result.score)

  @doc "Names the track played behind a card: the opening track of a listen, or the given artist and track."
  @spec preview(Listen.t()) :: Track.t() | nil
  def preview(%Listen{} = listen), do: preview(Listen.artist(listen), Listen.opening_track(listen))

  @spec preview(String.t() | nil, String.t() | nil) :: Track.t() | nil
  def preview(artist, name) when is_binary(artist) and is_binary(name), do: %Track{artist: artist, name: name}
  def preview(_artist, _name), do: nil

  @doc "Total minutes of the listens."
  @spec minutes([Listen.t()]) :: integer()
  def minutes(listens), do: listens |> Enum.map(&Listen.duration_ms/1) |> Enum.sum() |> div(60_000)

  @doc "The best-scored listens, best first; ties go to the most recent vote."
  @spec top([Listen.t()], integer()) :: [Listen.t()]
  def top(listens, count \\ 3) do
    listens
    |> Enum.filter(& &1.result.score)
    |> Enum.sort_by(&{&1.result.score, DateTime.to_unix(&1.result.voted_at)}, :desc)
    |> Enum.take(count)
  end

  @doc """
  The best-rated tracks, best first, at most one per album.

  Each album gives its best-rated track. Ties, inside an album and between albums, go to the track with the highest chat average, then to the most recent vote.
  """
  @spec top_tracks([Listen.t()], integer()) :: [map()]
  def top_tracks(listens, count) do
    listens
    |> Listen.tracks()
    |> Enum.group_by(& &1.entity.album_id)
    |> Enum.map(fn {_album_id, tracks} -> Enum.max_by(tracks, &track_rank/1) end)
    |> Enum.sort_by(&track_rank/1, :desc)
    |> Enum.take(count)
    |> Enum.map(&track_entry/1)
  end

  defp track_rank(%Listen{result: result}), do: {result.score, result.chat_score || 0.0, DateTime.to_unix(result.voted_at)}

  defp track_entry(%Listen{entity: track} = listen) do
    %{
      name: track.name,
      score: listen.result.score,
      album: track.album.name,
      artist: Listen.artist(listen),
      cover_url: Listen.cover_url(listen)
    }
  end
end
