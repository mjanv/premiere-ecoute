defmodule PremiereEcoute.Discography.Services.SyncPlaylistDiscography do
  @moduledoc """
  Syncs discography from a library playlist.

  Fetches the playlist from Spotify, skips if unchanged since last run (snapshot_id),
  then schedules EnrichDiscographyWorker for each artist whose albums are missing.
  Album creation and enrichment are handled entirely by the existing worker pipeline.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker

  @type result :: %{new_artists: non_neg_integer(), skipped_albums: non_neg_integer()}

  @spec sync(LibraryPlaylist.t()) :: {:ok, :unchanged} | {:ok, result()} | {:error, term()}
  def sync(%LibraryPlaylist{} = library_playlist) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(library_playlist.playlist_id),
         :changed <- check_snapshot(library_playlist, playlist) do
      {missing_tracks, skipped} = partition_tracks(playlist.tracks)

      artist_ids =
        missing_tracks
        |> Enum.map(& &1.artist_id)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)

      Enum.each(artist_ids, &schedule_artist/1)
      new_artists = length(artist_ids)

      LibraryPlaylist.update_submission_options(library_playlist, %{"snapshot_id" => playlist.snapshot_id})

      Logger.info(
        "playlist #{library_playlist.playlist_id} #{length(missing_tracks)} missing albums, #{new_artists} new artists scheduled, #{skipped} skipped"
      )

      {:ok, %{new_artists: new_artists, skipped_albums: skipped}}
    else
      :unchanged ->
        Logger.info("playlist #{library_playlist.playlist_id} skipped (unchanged)")
        {:ok, :unchanged}

      {:error, _} = error ->
        error
    end
  end

  defp check_snapshot(%LibraryPlaylist{metadata: metadata}, %{snapshot_id: snapshot_id}) do
    if metadata["snapshot_id"] == snapshot_id, do: :unchanged, else: :changed
  end

  defp partition_tracks(tracks) do
    tracks
    |> Enum.uniq_by(& &1.album_id)
    |> Enum.split_with(fn track -> is_nil(Album.find_by_provider(track.album_id, :spotify)) end)
    |> then(fn {missing, existing} -> {missing, length(existing)} end)
  end

  defp schedule_artist(artist_id) do
    artist_id
    |> Artist.find_by_provider(:spotify)
    |> case do
      %Artist{id: id} -> %{"id" => id}
      nil -> %{"spotify_id" => artist_id}
    end
    |> EnrichDiscographyWorker.now()
  end
end
