defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi.ReleaseGroups do
  @moduledoc """
  MusicBrainz release-groups API.

  A release-group is the abstract album concept, independent of specific editions or pressings.
  Searches and fetches release-group metadata with linked releases.
  """

  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi

  @doc """
  Searches MusicBrainz for release-groups matching a query.

  Accepts Lucene syntax, e.g. `releasegroup:"Discovery" AND artist:"Daft Punk"`.
  Returns up to 10 results with mbid, title, artist, primary_type, and first_release_date.
  """
  @spec search_release_groups(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_release_groups(query) when is_binary(query) do
    MusicBrainzApi.api()
    |> MusicBrainzApi.get(url: "/release-group", params: [query: query, limit: 10])
    |> MusicBrainzApi.handle(200, fn %{"release-groups" => groups} ->
      Enum.map(groups, fn g ->
        %{
          mbid: g["id"],
          title: g["title"],
          artist: primary_artist(g["artist-credit"]),
          primary_type: g["primary-type"],
          secondary_types: g["secondary-types"] || [],
          first_release_date: g["first-release-date"],
          score: g["score"]
        }
      end)
    end)
  end

  @doc """
  Fetches full details for a release-group by MBID.

  Includes artists and all linked releases (editions/pressings).
  Returns a map with mbid, title, artist, primary_type, first_release_date, and releases.
  """
  @spec get_release_group(String.t()) :: {:ok, map()} | {:error, term()}
  def get_release_group(mbid) when is_binary(mbid) do
    MusicBrainzApi.api()
    |> MusicBrainzApi.get(url: "/release-group/#{mbid}", params: [inc: "artists+releases"])
    |> MusicBrainzApi.handle(200, fn g ->
      %{
        mbid: g["id"],
        title: g["title"],
        artist: primary_artist(g["artist-credit"]),
        primary_type: g["primary-type"],
        secondary_types: g["secondary-types"] || [],
        first_release_date: g["first-release-date"],
        releases:
          Enum.map(g["releases"] || [], fn r ->
            %{
              mbid: r["id"],
              title: r["title"],
              date: r["date"],
              country: r["country"],
              status: r["status"],
              barcode: r["barcode"]
            }
          end)
      }
    end)
  end

  defp primary_artist([%{"artist" => artist} | _]), do: artist["name"]
  defp primary_artist(_), do: nil
end
