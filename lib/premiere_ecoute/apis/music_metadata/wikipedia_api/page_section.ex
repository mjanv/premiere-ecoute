defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageSection do
  @moduledoc """
  Wikipedia MediaWiki action API — single section HTML endpoint.

  Fetches the rendered HTML of one section of a Wikipedia page by its section index.
  Uses action=parse&prop=text&section=N on the en.wikipedia.org/w/api.php endpoint.

  Section index 0 is the lead/intro section (before any headings); 1 is the first
  named section, 2 the second, and so on (matching the ordinal position in the ToC).

  The returned HTML is sanitized via Floki: style blocks, footnotes, references,
  tables, figures, and edit-section links are removed. Anchor links are unwrapped
  (text kept). Bare <i> elements are annotated as search hotspots.
  """

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page

  # AIDEV-NOTE: tags removed entirely (element + all descendants).
  @remove_tags ~w(style script sup cite table figure)

  # AIDEV-NOTE: div/span class substrings that trigger full element removal.
  @remove_div_classes ~w(references thumb mw-references-wrap mw-editsection hatnote)

  @doc "Fetches and sanitizes the HTML of section N for the given Wikipedia page."
  @spec section(Page.t(), non_neg_integer()) :: {:ok, String.t()} | {:error, term()}
  def section(%Page{title: title}, index) when is_integer(index) and index >= 0 do
    params = [
      action: "parse",
      page: title,
      section: index,
      prop: "text",
      format: "json",
      disableeditsection: "1",
      disabletoc: "1"
    ]

    WikipediaApi.api()
    |> WikipediaApi.get(url: "/api.php", params: params)
    |> WikipediaApi.handle(200, &parse/1)
  end

  # AIDEV-NOTE: parse/1 returns the sanitized HTML string directly;
  # WikipediaApi.handle/3 wraps it in {:ok, html}.
  defp parse(%{"parse" => %{"text" => %{"*" => html}}}), do: sanitize(html)
  defp parse(_body), do: ""

  # AIDEV-NOTE: Uses Floki (DOM parser) instead of regex to avoid PCRE recursion
  # limit errors on large Wikipedia sections that contain embedded <style> blocks
  # (TemplateStyles) or deeply nested footnote HTML.
  defp sanitize(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.traverse_and_update(&transform_node/1)
    |> Floki.raw_html()
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  # Remove these tags entirely (tag + children).
  defp transform_node({tag, _attrs, _children} = node) when tag in @remove_tags do
    Floki.text(node)
    |> then(fn text -> if String.trim(text) == "", do: nil, else: nil end)
  end

  # Remove divs/spans whose class contains any of the @remove_div_classes substrings.
  defp transform_node({tag, attrs, children})
       when tag in ~w(div span section) do
    class = get_class(attrs)

    if Enum.any?(@remove_div_classes, &String.contains?(class, &1)) do
      nil
    else
      # Strip the tag but keep children (unwrap).
      children
    end
  end

  # Unwrap <a> links — keep the text/children, drop the element.
  defp transform_node({"a", _attrs, children}), do: children

  # Annotate bare <i> elements with a search query hotspot.
  # AIDEV-NOTE: Wikipedia uses <i> for album/song titles; this makes them
  # clickable even when the entity is not in the DB (falls back to ResolveQuery).
  defp transform_node({"i", attrs, children} = node) do
    text =
      node
      |> Floki.text()
      |> String.trim()

    if text != "" and get_class(attrs) == "" do
      attr_val = String.replace(text, "\"", "&quot;")

      {"i",
       [
         {"data-entity-id", attr_val},
         {"data-entity-type", "query"},
         {"class", "explorer-hotspot"}
       ], children}
    else
      node
    end
  end

  # Pass everything else through unchanged.
  defp transform_node(node), do: node

  defp get_class(attrs) do
    case List.keyfind(attrs, "class", 0) do
      {_, class} -> class
      nil -> ""
    end
  end
end
