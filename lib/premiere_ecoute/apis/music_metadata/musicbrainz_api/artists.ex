defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi.Artists do
  @moduledoc """
  MusicBrainz artists API.

  Searches and fetches artist metadata including type, country, life-span, and discography.
  """

  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi

  @doc """
  Searches MusicBrainz for artists matching a query.

  Accepts Lucene syntax, e.g. `artist:"Daft Punk"`.
  Returns up to 10 results with mbid, name, type, country, disambiguation, and score.
  """
  @spec search_artists(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_artists(query) when is_binary(query) do
    MusicBrainzApi.api()
    |> MusicBrainzApi.get(url: "/artist", params: [query: query, limit: 10])
    |> MusicBrainzApi.handle(200, fn %{"artists" => artists} ->
      Enum.map(artists, fn a ->
        %{
          mbid: a["id"],
          name: a["name"],
          sort_name: a["sort-name"],
          type: a["type"],
          country: a["country"],
          disambiguation: a["disambiguation"],
          score: a["score"]
        }
      end)
    end)
  end

  @doc """
  Fetches full details for an artist by MBID.

  Includes release-groups (discography).
  Returns a map with mbid, name, type, country, disambiguation, life_span, and release_groups.
  """
  @spec get_artist(String.t()) :: {:ok, map()} | {:error, term()}
  def get_artist(mbid) when is_binary(mbid) do
    MusicBrainzApi.api()
    |> MusicBrainzApi.get(url: "/artist/#{mbid}", params: [inc: "release-groups"])
    |> MusicBrainzApi.handle(200, fn a ->
      %{
        mbid: a["id"],
        name: a["name"],
        sort_name: a["sort-name"],
        type: a["type"],
        country: a["country"],
        disambiguation: a["disambiguation"],
        begin_area: get_in(a, ["begin-area", "name"]),
        life_span: %{
          begin: get_in(a, ["life-span", "begin"]),
          end: get_in(a, ["life-span", "end"]),
          ended: get_in(a, ["life-span", "ended"])
        },
        release_groups:
          Enum.map(a["release-groups"] || [], fn rg ->
            %{
              mbid: rg["id"],
              title: rg["title"],
              primary_type: rg["primary-type"],
              secondary_types: rg["secondary-types"] || [],
              first_release_date: rg["first-release-date"]
            }
          end)
      }
    end)
  end
end
