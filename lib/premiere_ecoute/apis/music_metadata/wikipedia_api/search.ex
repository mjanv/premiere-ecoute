defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Search do
  @moduledoc """
  Wikipedia search API.

  Searches Wikipedia pages by artist name or album title + artist.
  Uses the MediaWiki action=query&list=search endpoint.
  """

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi

  @base_wiki_url "https://en.wikipedia.org/wiki/"

  @doc """
  Searches Wikipedia for pages matching an artist name.

  Returns up to 5 results with page_id, title, and url.
  """
  @spec search_artist(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_artist(name) when is_binary(name) do
    WikipediaApi.api()
    |> WikipediaApi.get(
      url: "/api.php",
      params: [action: "query", list: "search", srsearch: name, format: "json", srlimit: 5, srnamespace: 0]
    )
    |> WikipediaApi.handle(200, &parse_results/1)
  end

  @doc """
  Searches Wikipedia for pages matching an album title and artist name.

  Returns up to 5 results with page_id, title, and url.
  """
  @spec search_album(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_album(title, artist) when is_binary(title) and is_binary(artist) do
    query = ~s(intitle:"#{title}" "#{artist}" album)

    WikipediaApi.api()
    |> WikipediaApi.get(
      url: "/api.php",
      params: [action: "query", list: "search", srsearch: query, format: "json", srlimit: 5, srnamespace: 0]
    )
    |> WikipediaApi.handle(200, &parse_results/1)
  end

  defp parse_results(%{"query" => %{"search" => results}}) do
    Enum.map(results, fn r ->
      %{
        page_id: r["pageid"],
        title: r["title"],
        url: @base_wiki_url <> URI.encode(r["title"])
      }
    end)
  end
end
