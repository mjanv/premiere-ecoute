defmodule PremiereEcoute.Discography.Services.EnrichAlbumLinks do
  @moduledoc """
  Enriches an album record with external links and provider IDs from third-party sources.

  Each source is fetched independently and stored only if the key is not already present.
  Sources already present are skipped without making an API call.

  The album's primary artist name (from `album.artist`) is used alongside the album title
  for all lookups to improve accuracy.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Discography.Album

  @doc """
  Enriches an album with all available external data.

  Runs each enrichment source independently. Returns `{:ok, album}` with the
  final state of the album after all sources have been attempted.
  """
  @spec enrich_album(Album.t()) :: {:ok, Album.t()} | {:error, term()}
  def enrich_album(%Album{} = album) do
    {:ok, album}
    |> enrich_wikipedia()
    |> enrich_deezer()
    |> enrich_spotify()
    |> enrich_tidal()
  end

  # Wikipedia — stores URL in external_links["wikipedia"], nil sentinel on not found
  defp enrich_wikipedia({:ok, %Album{external_links: %{"wikipedia" => _}} = album}) do
    {:ok, album}
  end

  defp enrich_wikipedia({:ok, %Album{name: name} = album}) do
    artist = artist_name(album)

    case WikipediaApi.search(artist: artist, album: name) do
      {:ok, [first | _]} ->
        Album.update(album, %{external_links: Map.put(album.external_links, "wikipedia", first.url)})

      {:ok, []} ->
        Logger.warning("EnrichAlbumLinks: no wikipedia page found for #{inspect(name)}")
        Album.update(album, %{external_links: Map.put(album.external_links, "wikipedia", nil)})

      {:error, reason} ->
        Logger.error("EnrichAlbumLinks: wikipedia lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, album}
    end
  end

  # Deezer — stores deezer ID in provider_ids[:deezer], nil sentinel on not found
  defp enrich_deezer({:error, _} = error), do: error

  defp enrich_deezer({:ok, %Album{provider_ids: %{deezer: _}} = album}) do
    {:ok, album}
  end

  defp enrich_deezer({:ok, %Album{name: name} = album}) do
    artist = artist_name(album)

    case DeezerApi.search_album(name, artist) do
      {:ok, [first | _]} ->
        Album.update(album, %{provider_ids: Map.put(album.provider_ids, :deezer, first.deezer_id)})

      {:ok, []} ->
        Logger.warning("EnrichAlbumLinks: no deezer album found for #{inspect(name)}")
        Album.update(album, %{provider_ids: Map.put(album.provider_ids, :deezer, nil)})

      {:error, reason} ->
        Logger.error("EnrichAlbumLinks: deezer lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, album}
    end
  end

  # Spotify — stores spotify ID in provider_ids[:spotify], nil sentinel on not found
  defp enrich_spotify({:error, _} = error), do: error

  defp enrich_spotify({:ok, %Album{provider_ids: %{spotify: _}} = album}) do
    {:ok, album}
  end

  defp enrich_spotify({:ok, %Album{name: name} = album}) do
    artist = artist_name(album)
    name_downcase = String.downcase(name)

    case SpotifyApi.search_albums("#{name} #{artist}") do
      {:ok, results} ->
        case Enum.find(results, &(String.downcase(&1.name) == name_downcase)) do
          %Album{provider_ids: %{spotify: id}} ->
            Album.update(album, %{provider_ids: Map.put(album.provider_ids, :spotify, id)})

          nil ->
            Logger.warning("EnrichAlbumLinks: no spotify album found for #{inspect(name)}")
            Album.update(album, %{provider_ids: Map.put(album.provider_ids, :spotify, nil)})
        end

      {:error, reason} ->
        Logger.error("EnrichAlbumLinks: spotify lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, album}
    end
  end

  # Tidal — stores tidal ID in provider_ids[:tidal], nil sentinel on not found
  defp enrich_tidal({:error, _} = error), do: error

  defp enrich_tidal({:ok, %Album{provider_ids: %{tidal: _}} = album}) do
    {:ok, album}
  end

  defp enrich_tidal({:ok, %Album{name: name} = album}) do
    artist = artist_name(album)

    case TidalApi.search_album(name, artist) do
      {:ok, [first | _]} ->
        Album.update(album, %{provider_ids: Map.put(album.provider_ids, :tidal, first.tidal_id)})

      {:ok, []} ->
        Logger.warning("EnrichAlbumLinks: no tidal album found for #{inspect(name)}")
        Album.update(album, %{provider_ids: Map.put(album.provider_ids, :tidal, nil)})

      {:error, reason} ->
        Logger.error("EnrichAlbumLinks: tidal lookup failed for #{inspect(name)}: #{inspect(reason)}")
        {:ok, album}
    end
  end

  # Returns the primary artist name string, or empty string if not set
  defp artist_name(%Album{artist: %{name: name}}) when is_binary(name), do: name
  defp artist_name(%Album{artist: name}) when is_binary(name), do: name
  defp artist_name(_), do: ""
end
