defmodule PremiereEcoute.Wrapped.ListenFixtures do
  @moduledoc """
  In-memory Wrapped listens, for tests that need no database.

  Album `n` is "Album n" by "Artist n", with the cover `https://i.scdn.co/image/n`, one 40-minute track "Intro n", heard in one session and first voted on the 1st of month `n` of 2026.
  """

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wrapped.Listen
  alias PremiereEcoute.Wrapped.Listen.Result

  @doc "Builds an album listen. `attrs` overrides the album (`name`, `cover_url`, `tracks`, `artists`) or its result (`score`, `chat_score`, `streamers`, `voted_at`)."
  @spec album_listen(integer(), map()) :: Listen.t()
  def album_listen(n, attrs \\ %{}), do: %Listen{entity: album(n, attrs), result: result(n, attrs)}

  @doc "Builds the listen of a rated track of album `n`. `attrs` takes `score`, `chat_score`, `voted_at` and `duration_ms`."
  @spec track_listen(integer(), String.t(), map()) :: Listen.t()
  def track_listen(n, name, attrs \\ %{}) do
    track = %Album.Track{name: name, album_id: n, album: album(n, %{}), duration_ms: attrs[:duration_ms]}

    %Listen{entity: track, result: result(n, attrs)}
  end

  @doc "Builds a single listen, Single n by Artist n. `attrs` overrides the single (`name`, `cover_url`, `duration_ms`) or its result."
  @spec single_listen(integer(), map()) :: Listen.t()
  def single_listen(n, attrs \\ %{}) do
    single = %Single{
      id: n,
      name: Map.get(attrs, :name, "Single #{n}"),
      cover_url: Map.get(attrs, :cover_url, "https://i.scdn.co/image/#{n}"),
      duration_ms: attrs[:duration_ms],
      artists: [%Artist{name: "Artist #{n}"}]
    }

    %Listen{entity: single, result: result(n, attrs)}
  end

  @doc "A vote time in 2026: `at(month)` or `at(month, day)`, at 20:00 UTC."
  @spec at(integer(), integer()) :: DateTime.t()
  def at(month, day \\ 1), do: DateTime.new!(Date.new!(2026, month, day), ~T[20:00:00])

  defp album(n, attrs) do
    %Album{
      id: n,
      name: Map.get(attrs, :name, "Album #{n}"),
      cover_url: Map.get(attrs, :cover_url, "https://i.scdn.co/image/#{n}"),
      artists: Map.get(attrs, :artists, [%Artist{name: "Artist #{n}"}]),
      tracks: Map.get(attrs, :tracks, [%Album.Track{name: "Intro #{n}", track_number: 1, duration_ms: 40 * 60_000}])
    }
  end

  defp result(n, attrs) do
    %Result{
      voted_at: Map.get(attrs, :voted_at, at(n)),
      score: attrs[:score],
      chat_score: attrs[:chat_score],
      streamers: Map.get(attrs, :streamers, ["streamer"])
    }
  end
end
