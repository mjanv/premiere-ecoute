defmodule PremiereEcoute.Discography.Workers.EnrichAlbumWorker do
  @moduledoc "Oban worker that fills external links and provider IDs for a specific or random unenriched album."

  use PremiereEcouteCore.Worker, queue: :discography, max_attempts: 3

  require Logger

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Services.EnrichAlbum
  alias PremiereEcoute.PubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}), do: run(Album.get(id))
  def perform(%Oban.Job{}), do: run(Album.random())

  def run(nil), do: {:error, :not_found}

  def run(%Album{} = album) do
    case EnrichAlbum.enrich_album(album) do
      {:ok, album} ->
        PubSub.broadcast("album:#{album.id}", {:album_enriched, album})
        Logger.info("album #{album.id} (#{album.name} by #{album.artist}) enriched")
        :ok

      {:error, reason} ->
        Logger.warning("album #{album.id} (#{album.name}) failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
