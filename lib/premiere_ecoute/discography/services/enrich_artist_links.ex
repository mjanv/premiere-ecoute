defmodule PremiereEcoute.Discography.Services.EnrichArtistLinks do
  @moduledoc """
  Enriches an artist record with external links and provider IDs from third-party sources.

  Each source is fetched independently and stored only if the key is not already present.
  Sources already present are skipped without making an API call.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Artist

  @doc """
  Enriches an artist with all available external data.

  Runs each enrichment source independently. Returns `{:ok, artist}` with the
  final state of the artist after all sources have been attempted.
  """
  @spec enrich_artist(Artist.t()) :: {:ok, Artist.t()}
  def enrich_artist(%Artist{} = artist) do
    {:ok, artist}
    |> enrich_wikipedia()
    |> enrich_deezer()
    |> enrich_spotify()
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

  # Deezer — stores deezer ID in provider_ids[:deezer], nil sentinel on not found
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

  # Spotify — stores spotify ID in provider_ids[:spotify], nil sentinel on not found
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
