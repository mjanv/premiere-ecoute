defmodule PremiereEcoute.Discography.Workers.EnrichDiscographyWorker do
  @moduledoc """
  Oban worker that orchestrates full enrichment of an artist's discography.

  This worker triggers a complete enrichment pipeline:
  1. Enrich the artist itself (external links, provider IDs)
  2. Fetch and persist all albums from Spotify
  3. For each album: enrich with external metadata
  4. For each track in each album: enrich with external metadata

  All enrichment tasks are scheduled as separate Oban jobs to enable
  queueing, concurrency handling, and resilience.
  """

  require Logger

  use PremiereEcouteCore.Worker, queue: :discography, max_attempts: 3

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichDiscography
  alias PremiereEcoute.Discography.Workers.EnrichAlbumWorker
  alias PremiereEcoute.Discography.Workers.EnrichArtistWorker
  # alias PremiereEcoute.Discography.Workers.EnrichTrackWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}), do: run(Artist.get(id))

  def perform(%Oban.Job{args: %{"spotify_id" => spotify_id}}) do
    with nil <- Artist.find_by_provider(spotify_id, :spotify),
         {:ok, fetched} <- Apis.spotify().get_artist(spotify_id),
         {:ok, created} <- Artist.create(fetched) do
      Logger.info("artist #{created.id} (#{created.name}) created from spotify_id #{spotify_id}")
      created
    else
      %Artist{} = artist -> artist
    end
    |> run()
  end

  def run(nil), do: {:error, :not_found}

  def run(%Artist{} = artist) do
    with {:ok, albums} <- EnrichDiscography.create_discography(artist),
         {:ok, _} <- EnrichArtistWorker.now(%{"id" => artist.id}),
         :ok <- EnrichAlbumWorker.interval(albums, fn album -> %{"id" => album.id} end) do
      Logger.info("artist #{artist.id} (#{artist.name}) #{length(albums)} albums scheduled")
      :ok
    else
      {:error, reason} ->
        Logger.warning("artist #{artist.id} (#{artist.name}) failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
