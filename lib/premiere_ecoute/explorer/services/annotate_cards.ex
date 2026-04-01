defmodule PremiereEcoute.Explorer.Services.AnnotateCards do
  @moduledoc """
  Annotates the card HTML of an Explorer node with interactive entity hotspots.

  Scans card content for artist and album names from the internal discography DB,
  then wraps each match with a `<mark>` element carrying `data-entity-id`,
  `data-entity-type`, and the `explorer-hotspot` CSS class.

  Annotation is server-side so the client receives pre-marked HTML. The JS canvas
  reads `data-entity-*` attributes on click and calls pushEvent("open_node", ...).

  Matching is done with word-boundary regex, longest-entity-first to prevent
  partial name matches (e.g. "Kanye" matching inside "Kanye West").
  """

  import Ecto.Query

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Explorer.Card
  alias PremiereEcoute.Explorer.Node
  alias PremiereEcoute.Repo

  # Load at most this many candidate entities to avoid excessive DB reads.
  @max_artists 300
  @max_albums 100

  @doc "Annotates all cards in the node with entity hotspot marks."
  @spec annotate(Node.t()) :: {:ok, Node.t()}
  def annotate(%Node{} = node) do
    entities = load_entities(node)

    annotated_cards =
      Enum.map(node.cards, fn %Card{} = card ->
        %Card{card | content_html: annotate_html(card.content_html, entities)}
      end)

    {:ok, %Node{node | cards: annotated_cards}}
  end

  # Load candidate entities: all artists (excluding the node's own artist) +
  # albums belonging to the node's artist (for richer annotation in discography cards).
  defp load_entities(%Node{entity_type: :artist, entity_id: entity_id}) when not is_nil(entity_id) do
    artists =
      from(a in Artist,
        where: a.id != ^entity_id,
        order_by: a.name,
        limit: @max_artists,
        select: {a.id, a.name, "artist"}
      )
      |> Repo.all()

    albums =
      from(a in Album,
        join: aa in "album_artists",
        on: aa.album_id == a.id,
        where: aa.artist_id == ^entity_id,
        limit: @max_albums,
        select: {a.id, a.name, "album"}
      )
      |> Repo.all()

    sort_by_length_desc(artists ++ albums)
  end

  defp load_entities(_node), do: []

  # Sort longest names first to prevent shorter names from matching inside longer ones.
  defp sort_by_length_desc(entities) do
    Enum.sort_by(entities, fn {_, name, _} -> -String.length(name) end)
  end

  # Replace occurrences of entity names in the HTML with annotated <mark> elements.
  # AIDEV-NOTE: pattern uses negative lookbehind/lookahead to avoid matching inside
  # HTML tags or across word boundaries. May still false-positive on very short names.
  defp annotate_html(html, []), do: html

  defp annotate_html(html, entities) do
    Enum.reduce(entities, html, fn {id, name, type}, acc ->
      escaped = Regex.escape(name)

      # Match the name when not preceded by a word character or "<",
      # and not followed by a word character or inside an HTML tag context.
      pattern = ~r/(?<![<\w\-])#{escaped}(?![\w\-]|[^<>]*>)/u

      replacement =
        ~s(<mark data-entity-id="#{id}" data-entity-type="#{type}" class="explorer-hotspot">#{name}</mark>)

      Regex.replace(pattern, acc, replacement)
    end)
  end
end
