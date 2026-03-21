defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi.Recordings do
  @moduledoc """
  MusicBrainz recordings API.

  Searches and fetches recording (track) metadata including MBIDs, ISRCs, and linked releases.
  """

  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi

  @doc """
  Searches MusicBrainz for recordings matching a query.

  Accepts Lucene syntax, e.g. `recording:"One More Time" AND artist:"Daft Punk"`.
  Returns up to 10 results with mbid, title, artist, duration_ms, isrcs, and first_release_date.
  """
  @spec search_recordings(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_recordings(query) when is_binary(query) do
    MusicBrainzApi.api()
    |> MusicBrainzApi.get(url: "/recording", params: [query: query, limit: 10])
    |> MusicBrainzApi.handle(200, fn %{"recordings" => recordings} ->
      Enum.map(recordings, fn r ->
        %{
          mbid: r["id"],
          title: r["title"],
          disambiguation: r["disambiguation"],
          artist: primary_artist(r["artist-credit"]),
          duration_ms: r["length"],
          isrcs: r["isrcs"] || [],
          first_release_date: r["first-release-date"],
          score: r["score"]
        }
      end)
    end)
  end

  @doc """
  Fetches full details for a recording by MBID.

  Includes artists, linked releases, and ISRCs.
  Returns a map with mbid, title, artist, duration_ms, isrcs, first_release_date, and releases.
  """
  @spec get_recording(String.t()) :: {:ok, map()} | {:error, term()}
  def get_recording(mbid) when is_binary(mbid) do
    MusicBrainzApi.api()
    |> MusicBrainzApi.get(url: "/recording/#{mbid}", params: [inc: "artists+releases+isrcs"])
    |> MusicBrainzApi.handle(200, fn r ->
      %{
        mbid: r["id"],
        title: r["title"],
        disambiguation: r["disambiguation"],
        artist: primary_artist(r["artist-credit"]),
        duration_ms: r["length"],
        isrcs: r["isrcs"] || [],
        first_release_date: r["first-release-date"],
        releases:
          Enum.map(r["releases"] || [], fn rel ->
            %{
              mbid: rel["id"],
              title: rel["title"],
              date: rel["date"],
              country: rel["country"],
              status: rel["status"]
            }
          end)
      }
    end)
  end

  defp primary_artist([%{"artist" => artist} | _]), do: artist["name"]
  defp primary_artist(_), do: nil
end
