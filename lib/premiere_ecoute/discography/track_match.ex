defmodule PremiereEcoute.Discography.TrackMatch do
  @moduledoc """
  Finds the Spotify track id of a song described only by what a media player reports.

  The desktop player cannot read the Spotify URI of what plays, only the title, the artist, the album, the track number and the length. This looks for a stored album track or single that fits, so the rest of the application can keep working with `spotify:track:<id>`.

  A song is matched on its title and an artist, within 3 seconds of length. The album and the track number only choose between candidates (the same song on an album and on a compilation), they never refuse one: a player may not report them. An unknown song gives `:error`, never a guess.
  """

  import Ecto.Query, warn: false

  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Repo

  @length_tolerance_ms 3_000

  @type wanted :: %{
          title: String.t(),
          artist: String.t(),
          album: String.t(),
          track_number: pos_integer() | nil,
          length_ms: non_neg_integer()
        }

  @type candidate :: %{
          id: String.t() | nil,
          title: String.t(),
          artists: [String.t()],
          album: String.t() | nil,
          track_number: integer() | nil,
          duration_ms: integer() | nil
        }

  @doc """
  Looks the song up in the stored albums and singles.
  """
  @spec find(wanted()) :: {:ok, String.t()} | :error
  def find(%{title: title} = wanted) do
    case String.downcase(String.trim(title)) do
      "" -> :error
      lowered -> lowered |> candidates() |> pick(wanted)
    end
  end

  @doc """
  Picks the best candidate for a song, or `:error` when none fits.

  Equal candidates are ordered by id, so the answer does not depend on the order of the list.
  """
  @spec pick([candidate()], wanted()) :: {:ok, String.t()} | :error
  def pick(candidates, wanted) do
    title = normalize(wanted.title)

    candidates
    |> Enum.filter(fn candidate ->
      candidate.id && title != "" && normalize(candidate.title) == title && artist?(candidate, wanted.artist) &&
        length?(candidate, wanted.length_ms)
    end)
    |> Enum.sort_by(&{-score(&1, wanted), &1.id})
    |> case do
      [best | _] -> {:ok, best.id}
      [] -> :error
    end
  end

  defp candidates(lowered_title) do
    tracks =
      from(t in Track,
        where: fragment("lower(?)", t.name) == ^lowered_title,
        preload: [album: :artists]
      )
      |> Repo.all()
      |> Enum.map(fn track ->
        %{
          id: Track.provider(track, :spotify),
          title: track.name,
          artists: Enum.map(track.album.artists, & &1.name),
          album: track.album.name,
          track_number: track.track_number,
          duration_ms: track.duration_ms
        }
      end)

    singles =
      from(s in Single,
        where: fragment("lower(?)", s.name) == ^lowered_title,
        preload: [:artists]
      )
      |> Repo.all()
      |> Enum.map(fn single ->
        %{
          id: Map.get(single.provider_ids, :spotify),
          title: single.name,
          artists: Enum.map(single.artists, & &1.name),
          album: single.name,
          track_number: nil,
          duration_ms: single.duration_ms
        }
      end)

    tracks ++ singles
  end

  # The player joins several artists in one line ("A, B", "A; B"): one known artist inside it is enough.
  defp artist?(%{artists: artists}, line) do
    line = normalize(line)
    Enum.any?(artists, fn artist -> (name = normalize(artist)) != "" and String.contains?(line, name) end)
  end

  defp length?(%{duration_ms: duration}, length_ms) when is_integer(duration) and duration > 0 and length_ms > 0,
    do: abs(duration - length_ms) <= @length_tolerance_ms

  defp length?(_candidate, _length_ms), do: true

  defp score(candidate, wanted) do
    album = if candidate.album && normalize(candidate.album) == normalize(wanted.album), do: 2, else: 0
    number = if wanted.track_number && candidate.track_number == wanted.track_number, do: 1, else: 0
    album + number
  end

  defp normalize(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.split()
    |> Enum.join(" ")
  end
end
