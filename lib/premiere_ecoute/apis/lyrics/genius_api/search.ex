defmodule PremiereEcoute.Apis.Lyrics.GeniusApi.Search do
  @moduledoc """
  Genius search API.

  Searches for songs by query string.
  """

  alias PremiereEcoute.Apis.Lyrics.GeniusApi

  @doc """
  Searches Genius for songs matching a query.

  Returns a list of song hits with id, title, artist, url, and thumbnail.
  """
  @spec search_song(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_song(query) when is_binary(query) do
    GeniusApi.api()
    |> GeniusApi.get(url: "/search", params: [q: query])
    |> GeniusApi.handle(200, fn %{"response" => %{"hits" => hits}} ->
      hits
      |> Enum.filter(fn hit -> hit["type"] == "song" end)
      |> Enum.map(fn %{"result" => result} ->
        %{
          id: result["id"],
          title: result["title"],
          full_title: result["full_title"],
          artist: result["primary_artist_names"],
          url: result["url"],
          thumbnail_url: result["song_art_image_thumbnail_url"],
          release_date: result["release_date_for_display"]
        }
      end)
    end)
  end
end
