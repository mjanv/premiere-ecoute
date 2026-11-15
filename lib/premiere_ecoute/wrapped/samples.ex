defmodule PremiereEcoute.Wrapped.Samples do
  @moduledoc """
  Made-up listens to preview a Wrapped without real votes.

  Read-only: albums come from the latest entries of the discography, scores, dates and streamers are invented.
  """

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wrapped.Listen
  alias PremiereEcoute.Wrapped.Listen.Result

  @scores [7.5, 9.0, 4.5, 8.0, 6.0, 9.5, 3.0, 7.0, 8.5, 5.5]
  @chat_scores [7.2, 6.1, 7.8, 8.3, 6.4]
  @streamers ["ana", "ben", "ana", "cy"]

  @doc "Builds made-up listens: the albums with a cover among the latest `count` of the discography (one every 20 days up to today), three rated tracks each, and a few singles."
  @spec listens(integer()) :: [Listen.t()]
  def listens(count \\ 14) do
    albums = count |> Discography.last_albums() |> Enum.filter(& &1.cover_url) |> Enum.sort_by(& &1.id)

    albums = albums |> Enum.with_index() |> Enum.map(fn {album, index} -> {album, result(index, length(albums))} end)

    Enum.flat_map(albums, &album/1) ++ (albums |> Enum.take(3) |> Enum.map(&single/1))
  end

  defp result(index, count) do
    %Result{
      voted_at: DateTime.add(DateTime.utc_now(:second), -(count - index) * 20, :day),
      score: Enum.at(@scores, rem(index, 10)),
      chat_score: Enum.at(@chat_scores, rem(index, 5)),
      streamers: [Enum.at(@streamers, rem(index, 4))]
    }
  end

  defp album({%Album{} = album, result}) do
    tracks =
      album.tracks
      |> Enum.sort_by(& &1.track_number)
      |> Enum.take(3)
      |> Enum.with_index()
      |> Enum.map(fn {track, i} ->
        %Listen{entity: %{track | album: album}, result: %{result | score: min(result.score + i, 10.0)}}
      end)

    [%Listen{entity: album, result: result} | tracks]
  end

  # No sample single in the discography: the opening track of an album stands in
  defp single({%Album{} = album, result}) do
    name = Listen.opening_track(%Listen{entity: album, result: result})

    %Listen{entity: %Single{id: album.id, name: name, cover_url: album.cover_url, artists: album.artists}, result: result}
  end
end
