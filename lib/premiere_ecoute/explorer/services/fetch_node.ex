defmodule PremiereEcoute.Explorer.Services.FetchNode do
  @moduledoc """
  Fetches and assembles an Explorer node for a resolved entity.

  For artist entities (internal DB or Wikipedia fallback):
  - Fetches Wikipedia summary (extract + thumbnail)
  - Fetches table of contents to identify relevant section indices
  - Fetches up to 3 named sections in parallel (Discography, Members, Career/History)
  - Assembles an intro card + section cards into a Node struct

  For album entities:
  - Builds a node from internal DB data (tracklist, release date, cover art)
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Explorer.Card
  alias PremiereEcoute.Explorer.Node

  # Sections to look for, in priority order; at most one card per type.
  # AIDEV-NOTE: section titles are matched case-insensitively against Wikipedia ToC.
  @target_sections [
    {"Discography", :discography},
    {"Albums", :discography},
    {"Career", :history},
    {"History", :history},
    {"Background", :history},
    {"Biography", :history},
    {"Early life", :history},
    {"Members", :members},
    {"Band members", :members},
    {"Current members", :members}
  ]

  @max_section_cards 3
  @section_fetch_timeout_ms 6_000

  @doc "Fetches and builds a Node for the given resolved entity."
  @spec fetch({:artist, Artist.t()} | {:album, Album.t()} | {:wikipedia, Page.t()}) ::
          {:ok, Node.t()} | {:error, term()}
  def fetch({:artist, %Artist{} = artist}) do
    with {:ok, page} <- resolve_wikipedia_page(artist),
         {:ok, summary} <- Apis.wikipedia().summary(page),
         {:ok, toc} <- Apis.wikipedia().table_of_contents(page) do
      # Fetch non-discography sections from Wikipedia (Career, Members, History…)
      other_sections =
        toc.sections
        |> Enum.reject(fn s ->
          String.downcase(s.title) in ["discography", "albums"]
        end)

      section_cards = fetch_section_cards(page, other_sections, "artist-#{artist.id}")

      intro_card = %Card{
        id: "artist-#{artist.id}-intro",
        type: :intro,
        title: artist.name,
        content_html: "<p>#{summary.extract}</p>"
      }

      # Build discography card from the internal DB — guaranteed clickable entries.
      # AIDEV-NOTE: DB discography replaces the Wikipedia "Discography" section so
      # album entries are actual entity hotspots rather than stripped plain text.
      disco_card = build_db_discography_card(artist)

      cards =
        [intro_card, disco_card | section_cards]
        |> Enum.filter(& &1)

      node = %Node{
        id: "artist-#{artist.id}",
        entity_type: :artist,
        entity_id: artist.id,
        entity_slug: artist.slug,
        label: artist.name,
        thumbnail_url: summary.thumbnail_url,
        cards: cards
      }

      {:ok, node}
    end
  end

  def fetch({:album, %Album{} = album}) do
    artist_name =
      case album.artists do
        [artist | _] -> artist.name
        _ -> nil
      end

    tracks_html = build_tracklist_html(album.tracks)

    tracklist_card = %Card{
      id: "album-#{album.id}-tracklist",
      type: :discography,
      title: "Tracklist",
      content_html: tracks_html
    }

    intro_card = %Card{
      id: "album-#{album.id}-intro",
      type: :intro,
      title: album.name,
      content_html: build_album_intro_html(album, artist_name)
    }

    node = %Node{
      id: "album-#{album.id}",
      entity_type: :album,
      entity_id: album.id,
      entity_slug: album.slug,
      label: album.name,
      subtitle: artist_name,
      thumbnail_url: album.cover_url,
      cards: [intro_card, tracklist_card]
    }

    {:ok, node}
  end

  def fetch({:track, %Track{} = track}) do
    node = %Node{
      id: "track-#{track.id}",
      entity_type: :track,
      entity_id: track.id,
      entity_slug: track.slug,
      label: track.name,
      provider_ids: track.provider_ids,
      cards: []
    }

    {:ok, node}
  end

  def fetch({:wikipedia, %Page{} = page}) do
    with {:ok, summary} <- Apis.wikipedia().summary(page),
         {:ok, toc} <- Apis.wikipedia().table_of_contents(page) do
      section_cards = fetch_section_cards(page, toc.sections, "wiki-#{page.id}")

      intro_card = %Card{
        id: "wiki-#{page.id}-intro",
        type: :intro,
        title: summary.title,
        content_html: "<p>#{summary.extract}</p>"
      }

      node = %Node{
        id: "wiki-#{page.id}",
        entity_type: :artist,
        entity_id: nil,
        entity_slug: nil,
        label: summary.title,
        thumbnail_url: summary.thumbnail_url,
        cards: [intro_card | section_cards]
      }

      {:ok, node}
    end
  end

  # Resolve the Wikipedia page for an artist, using stored URL first.
  defp resolve_wikipedia_page(%Artist{external_links: links, name: name}) do
    case links["wikipedia"] do
      nil ->
        case Apis.wikipedia().search(artist: name) do
          {:ok, [page | _]} -> {:ok, page}
          {:ok, []} -> {:error, :wikipedia_not_found}
          error -> error
        end

      url ->
        title =
          url
          |> URI.parse()
          |> Map.get(:path, "")
          |> String.split("/")
          |> List.last()
          |> URI.decode()

        {:ok, %Page{title: title, url: url}}
    end
  end

  # Select sections from the ToC, at most @max_section_cards, one per card type.
  defp select_sections(sections) do
    sections_with_index = Enum.with_index(sections, 1)

    Enum.reduce(@target_sections, [], fn {title, type}, acc ->
      if Enum.any?(acc, fn {_s, t, _i} -> t == type end) do
        acc
      else
        case Enum.find(sections_with_index, fn {s, _i} ->
               String.downcase(s.title) == String.downcase(title)
             end) do
          nil -> acc
          {section, index} -> [{section, type, index} | acc]
        end
      end
    end)
    |> Enum.reverse()
    |> Enum.take(@max_section_cards)
  end

  # Fetch section HTML in parallel, dropping failures and empty sections.
  defp fetch_section_cards(page, toc_sections, id_prefix) do
    selected = select_sections(toc_sections)

    selected
    |> Task.async_stream(
      fn {section, type, index} ->
        case Apis.wikipedia().section(page, index) do
          {:ok, html} when byte_size(html) > 50 ->
            {:ok,
             %Card{
               id: "#{id_prefix}-#{index}",
               type: type,
               title: section.title,
               content_html: html
             }}

          _ ->
            {:error, :empty}
        end
      end,
      timeout: @section_fetch_timeout_ms,
      on_timeout: :kill_task,
      ordered: true
    )
    |> Stream.filter(fn
      {:ok, {:ok, _}} -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, {:ok, card}} -> card end)
  end

  # Build a discography card from the internal DB album list for the artist.
  # Each entry is an HTML row with data-entity-id / data-entity-type so the
  # JS click handler can open an album node without going through annotation.
  defp build_db_discography_card(%Artist{id: artist_id, name: name}) do
    albums =
      Discography.list_albums_for_artist(artist_id)
      |> Enum.sort_by(& &1.release_date, {:desc, Date})

    if albums == [] do
      nil
    else
      rows =
        Enum.map(albums, fn album ->
          year = if album.release_date, do: " · #{album.release_date.year}", else: ""

          """
          <div class="explorer-album-row" data-entity-id="#{album.id}" data-entity-type="album">
            <span class="explorer-album-row__name">#{album.name}</span>
            <span class="explorer-album-row__meta">#{year}</span>
          </div>
          """
        end)
        |> Enum.join()

      %Card{
        id: "artist-#{artist_id}-discography",
        type: :discography,
        title: "Discography",
        content_html: "<p class=\"text-xs text-gray-500 mb-2\">#{length(albums)} releases in #{name}'s catalogue</p>" <> rows
      }
    end
  end

  defp build_album_intro_html(album, artist_name) do
    parts = [
      if(artist_name, do: "<p><strong>#{artist_name}</strong></p>"),
      if(album.release_date, do: "<p>Released: #{album.release_date}</p>"),
      if(album.total_tracks, do: "<p>#{album.total_tracks} tracks</p>")
    ]

    parts
    |> Enum.filter(& &1)
    |> Enum.join("\n")
  end

  defp build_tracklist_html(tracks) when is_list(tracks) do
    items =
      tracks
      |> Enum.sort_by(& &1.track_number)
      |> Enum.map(fn t ->
        duration = format_duration(t.duration_ms)

        """
        <li class="explorer-track-row" data-entity-id="#{t.id}" data-entity-type="track">
          <span class="explorer-track-row__number">#{t.track_number}.</span>
          <span class="explorer-track-row__name">#{t.name}</span>
          #{if duration, do: ~s(<span class="explorer-track-row__duration">#{duration}</span>), else: ""}
        </li>
        """
      end)
      |> Enum.join()

    "<ol>#{items}</ol>"
  end

  defp build_tracklist_html(_), do: "<p>No tracks available.</p>"

  defp format_duration(nil), do: nil

  defp format_duration(ms) do
    seconds = div(ms, 1000)
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
