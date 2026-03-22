defmodule PremiereEcoute.Discography.Workers.EnrichAlbumLinksWorker do
  @moduledoc "Oban worker that fills external links and provider IDs for a specific or random unenriched album."

  use Oban.Worker, queue: :discography, max_attempts: 3

  require Logger

  import Ecto.Query

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Services.EnrichAlbumLinks
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"slug" => slug}}) do
    case Album.get_album_by_slug(slug) do
      nil ->
        Logger.error("EnrichAlbumLinks: album not found for slug #{inspect(slug)}")
        {:error, :not_found}

      album ->
        run(album)
    end
  end

  def perform(%Oban.Job{}) do
    album =
      from(a in Album,
        where:
          fragment("? \\? 'wikipedia' = false", a.external_links) or
            fragment("NOT (? \\? 'deezer')", a.provider_ids) or
            fragment("NOT (? \\? 'spotify')", a.provider_ids) or
            fragment("NOT (? \\? 'tidal')", a.provider_ids)
      )
      |> order_by(fragment("RANDOM()"))
      |> limit(1)
      |> Repo.one()
      |> Album.preload()

    case album do
      nil ->
        Logger.info("EnrichAlbumLinks: no unenriched albums remaining")
        :ok

      album ->
        run(album)
    end
  end

  def run(%Album{name: name} = album) do
    Logger.info("EnrichAlbumLinks: enriching album #{inspect(name)}")

    case EnrichAlbumLinks.enrich_album(album) do
      {:ok, enriched} ->
        Logger.info("EnrichAlbumLinks: enriched #{inspect(name)}")
        PubSub.broadcast("album:#{album.id}", {:album_enriched, enriched})
        :ok

      {:error, reason} ->
        Logger.error("EnrichAlbumLinks: failed to enrich #{inspect(name)}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
