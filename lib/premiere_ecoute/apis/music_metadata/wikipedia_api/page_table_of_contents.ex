defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageTableOfContents do
  @moduledoc """
  Wikipedia MediaWiki action API — table of contents endpoint.

  Fetches the structured list of sections for a page by title, without
  any section text content. Uses action=parse&prop=tocdata on the
  en.wikipedia.org/w/api.php endpoint.
  """

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Section
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.TableOfContents

  @doc "Fetches the table of contents for a Wikipedia page by its exact title."
  @spec table_of_contents(Page.t()) :: {:ok, TableOfContents.t()} | {:error, term()}
  def table_of_contents(%Page{title: title}) do
    params = [action: "parse", page: title, prop: "tocdata", format: "json"]

    WikipediaApi.api()
    |> WikipediaApi.get(url: "/api.php", params: params)
    |> WikipediaApi.handle(200, &parse/1)
  end

  defp parse(%{"parse" => %{"title" => title, "pageid" => page_id, "tocdata" => %{"sections" => sections}}}) do
    %TableOfContents{
      title: title,
      page_id: page_id,
      sections: Enum.map(sections, &parse_section/1)
    }
  end

  defp parse_section(section) do
    %Section{
      number: section["number"],
      title: String.replace(section["line"], ~r/<[^>]+>/, ""),
      level: section["tocLevel"],
      anchor: section["anchor"]
    }
  end
end
