defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.Artists do
  @moduledoc """
  Tidal artists API.

  Fetches artist data and albums from Tidal Open API v2.

  AIDEV-NOTE: Tidal v2 uses JSON:API format. Artist images are in `included` artworks,
  linked via relationships.profileArt. search_artist/1 filters results to exact name
  matches (case-insensitive) to avoid false positives from Tidal's fuzzy search ranking.
  """

  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi.Parser
  alias PremiereEcoute.Discography.Artist

  @doc """
  Fetches an artist by Tidal ID.

  Uses `?include=profileArt` to embed artwork in the response. Images are parsed
  from included artworks linked via relationships.profileArt.
  """
  @spec get_artist(String.t()) :: {:ok, Artist.t()} | {:error, term()}
  def get_artist(artist_id) when is_binary(artist_id) do
    TidalApi.api()
    |> TidalApi.get(url: "/artists", params: [{"filter[id]", artist_id}, {"include", "profileArt"}, {"countryCode", "US"}])
    |> TidalApi.handle(200, fn data ->
      artist_data = hd(data["data"])
      artwork_id = get_in(artist_data, ["relationships", "profileArt", "data", Access.at(0), "id"])
      images = Parser.parse_artworks(data["included"] || [], artwork_id)

      %Artist{
        provider_ids: %{tidal: artist_data["id"]},
        name: artist_data["attributes"]["name"],
        images: images
      }
    end)
  end

  @doc """
  Searches Tidal for artists matching a name.

  Uses GET /v2/searchResults/{query}?include=artists. Returns only exact name matches
  (case-insensitive) with tidal_id, name, and popularity.
  """
  @spec search_artist(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_artist(name) when is_binary(name) do
    name_downcase = String.downcase(name)

    TidalApi.api()
    |> TidalApi.get(
      url: "/searchResults/#{URI.encode(name)}",
      params: [{"include", "artists"}, {"explicitFilter", "INCLUDE"}, {"countryCode", "US"}]
    )
    |> TidalApi.handle(200, fn data ->
      (data["included"] || [])
      |> Enum.filter(&(&1["type"] == "artists" && String.downcase(&1["attributes"]["name"]) == name_downcase))
      |> Enum.map(fn a ->
        %{
          tidal_id: a["id"],
          name: a["attributes"]["name"],
          popularity: a["attributes"]["popularity"]
        }
      end)
    end)
  end

  @doc """
  Fetches albums for an artist by Tidal ID.

  Returns a list of album maps (without tracks). Cover URL is derived from the album's
  external Tidal sharing link since the coverArt include is not available in this context.
  """
  @spec get_artist_albums(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_artist_albums(artist_id) when is_binary(artist_id) do
    TidalApi.api()
    |> TidalApi.get(url: "/artists", params: [{"filter[id]", artist_id}, {"include", "albums"}, {"countryCode", "US"}])
    |> TidalApi.handle(200, fn data ->
      Enum.map(data["included"] || [], fn album ->
        %{
          provider_ids: %{tidal: album["id"]},
          name: album["attributes"]["title"],
          release_date: Parser.parse_release_date(album["attributes"]["releaseDate"]),
          cover_url: Parser.parse_tidal_url(album["attributes"]["externalLinks"] || [])
        }
      end)
    end)
  end
end
