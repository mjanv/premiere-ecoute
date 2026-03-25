defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageSummary do
  @moduledoc """
  Wikipedia REST API — page summary endpoint.

  Fetches the introduction extract and thumbnail for a page by title.
  Uses the en.wikipedia.org/api/rest_v1/page/summary/:title endpoint,
  which is separate from the MediaWiki action API.
  """

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Summary

  @doc "Fetches the summary for a Wikipedia page by its exact title."
  @spec summary(Page.t()) :: {:ok, Summary.t()} | {:error, term()}
  def summary(%Page{title: title}) do
    WikipediaApi.rest_api()
    |> WikipediaApi.get(url: "/page/summary/#{URI.encode(title)}")
    |> WikipediaApi.handle(200, &parse/1)
  end

  defp parse(body) do
    %Summary{
      title: body["title"],
      extract: body["extract"],
      thumbnail_url: get_in(body, ["thumbnail", "source"]),
      page_url: get_in(body, ["content_urls", "desktop", "page"])
    }
  end
end
