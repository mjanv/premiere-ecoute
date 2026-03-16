require Logger

alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
alias PremiereEcoute.Discography.Artist

# Ensure a client credentials token is available
case SpotifyApi.client_credentials() do
  {:ok, _} -> Logger.info("Spotify token acquired")
  {:error, reason} -> raise "Failed to acquire Spotify token: #{inspect(reason)}"
end

artists =
  Artist.all()
  |> Enum.filter(fn artist -> map_size(artist.provider_ids) == 0 end)

Logger.info("Found #{length(artists)} artist(s) without Spotify data")

results =
  Enum.map(artists, fn artist ->
    Logger.info("Processing: #{artist.name}")

    with {:ok, %{id: spotify_id}} <- SpotifyApi.search_artist(artist.name),
         {:ok, spotify_artist} <- SpotifyApi.get_artist(spotify_id) do
      case Artist.update(artist, %{
             provider_ids: %{spotify: spotify_id},
             images: Enum.map(spotify_artist.images, &Map.from_struct/1)
           }) do
        {:ok, updated} ->
          Logger.info("  ✓ #{artist.name} → #{spotify_id} (#{length(updated.images)} images)")
          {:ok, updated}

        {:error, changeset} ->
          Logger.error("  ✗ #{artist.name}: failed to update — #{inspect(changeset.errors)}")
          {:error, artist.name}
      end
    else
      {:ok, nil} ->
        Logger.warning("  ✗ #{artist.name}: not found on Spotify")
        {:skip, artist.name}

      {:error, reason} ->
        Logger.error("  ✗ #{artist.name}: API error — #{inspect(reason)}")
        {:error, artist.name}
    end
  end)

ok = Enum.count(results, &match?({:ok, _}, &1))
skipped = Enum.count(results, &match?({:skip, _}, &1))
errors = Enum.count(results, &match?({:error, _}, &1))

Logger.info("Done — #{ok} updated, #{skipped} not found, #{errors} errors")
