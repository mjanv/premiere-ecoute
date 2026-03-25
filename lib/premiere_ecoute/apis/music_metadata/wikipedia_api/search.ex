defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Search do
  @moduledoc """
  Wikipedia search API.
  """

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page

  @base_url "https://en.wikipedia.org/wiki/"

  @type query :: [
          artist: String.t(),
          album: String.t()
        ]

  @doc """
  Searches Wikipedia pages matching either 

    - an artist name
    - an album title and artist name

  Returns up to 5 results with page_id, title, and url.
  """
  @spec search(query()) :: {:ok, [Page.t()]} | {:error, term()}
  def search(query) do
    srsearch =
      case query do
        [artist: artist, album: album] -> ~s(intitle:"#{album}" "#{artist}" album)
        [artist: artist] -> ~s("#{artist}")
      end

    params = [action: "query", list: "search", srsearch: srsearch, format: "json", srlimit: 5, srnamespace: 0]

    WikipediaApi.api()
    |> WikipediaApi.get(url: "/api.php", params: params)
    |> WikipediaApi.handle(200, &parse_results/1)
  end

  defp parse_results(%{"query" => %{"search" => results}}) do
    Enum.map(results, fn r ->
      %Page{id: r["pageid"], title: r["title"], url: @base_url <> URI.encode(r["title"])}
    end)
  end
end
