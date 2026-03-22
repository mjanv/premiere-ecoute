defmodule PremiereEcoute.Discography.Services.EnrichArtistLinks do
  @moduledoc """
  Enriches an artist record with external links and provider IDs from third-party sources.

  Each source is fetched independently and stored only if the key is not already present.
  Sources already present are skipped without making an API call.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Discography.Artist

  @doc """
  Enriches an artist with all available external data.

  Runs each enrichment source independently. Returns `{:ok, artist}` with the
  final state of the artist after all sources have been attempted.
  """
  @spec enrich_artist(Artist.t()) :: {:ok, Artist.t()} | {:error, term()}
  def enrich_artist(%Artist{} = artist) do
    {:ok, artist}
    |> enrich_wikipedia()
    |> enrich_genius()
    |> enrich_deezer()
    |> enrich_spotify()
    |> enrich_tidal()
    |> enrich_youtube()
  end

  # Wikipedia — stores URL in external_links["wikipedia"], nil sentinel on not found
  defp enrich_wikipedia({:ok, %Artist{external_links: %{"wikipedia" => _}} = artist}) do
    {:ok, artist}
  end

  defp enrich_wikipedia({:ok, %Artist{name: name} = artist}) do
    case WikipediaApi.search_artist(name) do
      {:ok, [first | _]} ->
        Artist.update(artist, %{external_links: Map.put(artist.external_links, "wikipedia", first.url)})

      {:ok, []} ->
        Logger.warning("EnrichArtistLinks: no wikipedia page found for #{inspect(name)}")
        Artist.update(artist, %{external_links: Map.put(artist.external_links, "wikipedia", nil)})

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: wikipedia lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, artist}
    end
  end

  # Genius — stores artist URL in external_links["genius"], nil sentinel on not found
  defp enrich_genius({:error, _} = error), do: error

  defp enrich_genius({:ok, %Artist{external_links: %{"genius" => _}} = artist}) do
    {:ok, artist}
  end

  defp enrich_genius({:ok, %Artist{name: name} = artist}) do
    case GeniusApi.search_artist(name) do
      {:ok, %{url: url}} ->
        Artist.update(artist, %{external_links: Map.put(artist.external_links, "genius", url)})

      {:ok, nil} ->
        Logger.warning("EnrichArtistLinks: no genius page found for #{inspect(name)}")
        Artist.update(artist, %{external_links: Map.put(artist.external_links, "genius", nil)})

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: genius lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, artist}
    end
  end

  # Deezer — stores deezer ID in provider_ids[:deezer], nil sentinel on not found
  defp enrich_deezer({:error, _} = error), do: error

  defp enrich_deezer({:ok, %Artist{provider_ids: %{deezer: _}} = artist}) do
    {:ok, artist}
  end

  defp enrich_deezer({:ok, %Artist{name: name} = artist}) do
    case DeezerApi.search_artist(name) do
      {:ok, [first | _]} ->
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :deezer, first.deezer_id)})

      {:ok, []} ->
        Logger.warning("EnrichArtistLinks: no deezer page found for #{inspect(name)}")
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :deezer, nil)})

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: deezer lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, artist}
    end
  end

  # Tidal — stores tidal ID in provider_ids[:tidal], nil sentinel on not found
  defp enrich_tidal({:error, _} = error), do: error

  defp enrich_tidal({:ok, %Artist{provider_ids: %{tidal: _}} = artist}) do
    {:ok, artist}
  end

  defp enrich_tidal({:ok, %Artist{name: name} = artist}) do
    case TidalApi.search_artist(name) do
      {:ok, [first | _]} ->
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :tidal, first.tidal_id)})

      {:ok, []} ->
        Logger.warning("EnrichArtistLinks: no tidal page found for #{inspect(name)}")
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :tidal, nil)})

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: tidal lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, artist}
    end
  end

  # YouTube Music — stores YouTube channel ID in provider_ids[:youtube_music], nil sentinel on not found
  defp enrich_youtube({:error, _} = error), do: error

  defp enrich_youtube({:ok, %Artist{provider_ids: %{youtube_music: _}} = artist}) do
    {:ok, artist}
  end

  defp enrich_youtube({:ok, %Artist{name: name} = artist}) do
    case YoutubeApi.search_artist(name) do
      {:ok, [first | _]} ->
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :youtube_music, first.channel_id)})

      {:ok, []} ->
        Logger.warning("EnrichArtistLinks: no youtube channel found for #{inspect(name)}")
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :youtube_music, nil)})

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: youtube lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, artist}
    end
  end

  # Spotify — stores spotify ID in provider_ids[:spotify], nil sentinel on not found
  defp enrich_spotify({:error, _} = error), do: error

  defp enrich_spotify({:ok, %Artist{provider_ids: %{spotify: _}} = artist}) do
    {:ok, artist}
  end

  defp enrich_spotify({:ok, %Artist{name: name} = artist}) do
    case SpotifyApi.search_artist(name) do
      {:ok, %{id: id}} ->
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :spotify, id)})

      {:ok, nil} ->
        Logger.warning("EnrichArtistLinks: no spotify page found for #{inspect(name)}")
        Artist.update(artist, %{provider_ids: Map.put(artist.provider_ids, :spotify, nil)})

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: spotify lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, artist}
    end
  end
end
