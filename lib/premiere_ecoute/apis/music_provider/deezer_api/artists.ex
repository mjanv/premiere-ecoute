defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.Artists do
  @moduledoc """
  Deezer artists API.

  Fetches artist data and albums from Deezer API.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Parser
  alias PremiereEcoute.Discography.Artist

  @doc """
  Fetches an artist by Deezer ID.

  Returns an Artist struct with provider_ids and images populated.
  """
  @spec get_artist(String.t()) :: {:ok, Artist.t()} | {:error, term()}
  def get_artist(artist_id) when is_binary(artist_id) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/artist/#{artist_id}")
    |> DeezerApi.handle(200, fn data ->
      %Artist{
        provider_ids: %{deezer: data["id"]},
        name: data["name"],
        images: [
          %Artist.Image{url: data["picture_small"], height: 56, width: 56},
          %Artist.Image{url: data["picture_medium"], height: 250, width: 250},
          %Artist.Image{url: data["picture_big"], height: 500, width: 500},
          %Artist.Image{url: data["picture_xl"], height: 1000, width: 1000}
        ]
      }
    end)
  end

  @doc """
  Searches Deezer for artists matching a name.

  Returns up to 5 results with deezer_id, name, and nb_fan.
  """
  @spec search_artist(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_artist(name) when is_binary(name) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/search/artist", params: [q: name, limit: 5])
    |> DeezerApi.handle(200, fn %{"data" => items} ->
      Enum.map(items, fn a ->
        %{
          deezer_id: to_string(a["id"]),
          name: a["name"],
          nb_fan: a["nb_fan"]
        }
      end)
    end)
  end

  @doc """
  Searches Deezer for albums matching a title and artist name.

  Returns only exact title matches (case-insensitive) with deezer_id and name.
  """
  @spec search_album(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_album(title, artist) when is_binary(title) and is_binary(artist) do
    title_downcase = String.downcase(title)

    DeezerApi.api()
    |> DeezerApi.get(url: "/search/album", params: [q: "#{title} #{artist}", limit: 10])
    |> DeezerApi.handle(200, fn %{"data" => items} ->
      items
      |> Enum.filter(&(String.downcase(&1["title"]) == title_downcase))
      |> Enum.map(fn a ->
        %{
          deezer_id: to_string(a["id"]),
          name: a["title"]
        }
      end)
    end)
  end

  @doc """
  Fetches albums for an artist by Deezer ID.

  Returns a list of album maps (without tracks).
  """
  @spec get_artist_albums(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_artist_albums(artist_id) when is_binary(artist_id) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/artist/#{artist_id}/albums")
    |> DeezerApi.handle(200, fn %{"data" => items} ->
      Enum.map(items, fn data ->
        %{
          provider_ids: %{deezer: data["id"]},
          name: data["title"],
          release_date: Parser.parse_release_date(data["release_date"]),
          cover_url: data["cover"]
        }
      end)
    end)
  end
end
