defmodule PremiereEcoute.Discography.Services.EnrichArtist do
  @moduledoc """
  Enriches an artist record with external links and provider IDs from third-party sources.

  Each source is fetched independently and stored. All providers are always queried.

  The artist's name is used for all lookups.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Supervisor

  @doc """
  Enriches an artist with all available external data.

  Runs each enrichment source independently. Returns `{:ok, artist}` with the
  final state of the artist after all sources have been attempted.
  """
  @spec enrich_artist(Artist.t()) :: {:ok, Artist.t()} | {:error, term()}
  def enrich_artist(%Artist{} = artist) do
    external_links =
      [:wikipedia, :genius]
      |> Supervisor.async(fn k -> {k, enrich(k, artist)} end)
      |> then(&Map.merge(artist.external_links, &1))

    provider_ids =
      [:spotify, :deezer, :tidal, :youtube_music]
      |> Supervisor.async(fn k -> {k, enrich(k, artist)} end)
      |> then(&Map.merge(artist.provider_ids, &1))

    Artist.update(artist, %{external_links: external_links, provider_ids: provider_ids})
  end

  defp enrich(:wikipedia, %Artist{name: name}) do
    case WikipediaApi.search(artist: name) do
      {:ok, [%{url: url} | _]} -> url
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:genius, %Artist{name: name}) do
    case GeniusApi.search_artist(name) do
      {:ok, %{url: url}} -> url
      {:ok, nil} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:deezer, %Artist{name: name}) do
    case DeezerApi.search_artist(name) do
      {:ok, [%{deezer_id: deezer_id} | _]} -> deezer_id
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:spotify, %Artist{name: name}) do
    case SpotifyApi.search_artist(name) do
      {:ok, %{id: id}} -> id
      {:ok, nil} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:tidal, %Artist{name: name}) do
    case TidalApi.search_artist(name) do
      {:ok, [%{tidal_id: tidal_id} | _]} -> tidal_id
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end

  defp enrich(:youtube_music, %Artist{name: name}) do
    case YoutubeApi.search_artist(name) do
      {:ok, [%{channel_id: channel_id} | _]} -> channel_id
      {:ok, []} -> nil
      {:error, _reason} -> nil
    end
  end
end
