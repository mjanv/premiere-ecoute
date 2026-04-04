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

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichDiscography
  alias PremiereEcoute.Discography.Workers.EnrichAlbumWorker
  alias PremiereEcoute.Discography.Workers.EnrichArtistWorker
  alias PremiereEcoute.Discography.Workers.EnrichTrackWorker
  alias PremiereEcoute.PubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}), do: run(Artist.get(id))

  def run(nil), do: {:error, :not_found}

  def run(%Artist{} = artist) do
    with {:ok, albums} <- EnrichDiscography.create_discography(artist),
         tracks <- Enum.flat_map(albums, fn album -> album.tracks end),
         :ok <- PubSub.broadcast("artist:#{artist.id}", {:discography_enriched, artist}),
         {:ok, _} <- EnrichArtistWorker.now(%{"id" => artist.id}),
         :ok <- Enum.each(albums, fn album -> EnrichAlbumWorker.now(%{"id" => album.id}) end),
         :ok <- Enum.each(tracks, fn track -> EnrichTrackWorker.now(%{"id" => track.id}) end) do
      :ok
    else
      {:error, reason} -> Logger.warning("Failed to enrich discography for artist #{artist.id}: #{inspect(reason)}")
    end
  end
end
