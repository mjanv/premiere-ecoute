defmodule PremiereEcoute.Discography.Workers.EnrichArtistLinksWorker do
  @moduledoc "Oban worker that fills external links and provider IDs for a specific or random unenriched artist."

  use Oban.Worker, queue: :discography, max_attempts: 3

  require Logger

  import Ecto.Query

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichArtistLinks
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"slug" => slug}}) do
    case Artist.get_by_slug(slug) do
      nil ->
        Logger.error("EnrichArtistLinks: artist not found for slug #{inspect(slug)}")
        {:error, :not_found}

      artist ->
        run(artist)
    end
  end

  def perform(%Oban.Job{}) do
    artist =
      from(a in Artist,
        where:
          fragment("? \\? 'wikipedia' = false", a.external_links) or
            fragment("? \\? 'genius' = false", a.external_links) or
            fragment("NOT (? \\? 'deezer')", a.provider_ids) or
            fragment("NOT (? \\? 'spotify')", a.provider_ids)
      )
      |> order_by(fragment("RANDOM()"))
      |> limit(1)
      |> Repo.one()

    case artist do
      nil ->
        Logger.info("EnrichArtistLinks: no unenriched artists remaining")
        :ok

      artist ->
        run(artist)
    end
  end

  def run(%Artist{name: name} = artist) do
    Logger.info("EnrichArtistLinks: enriching artist #{inspect(name)}")

    case EnrichArtistLinks.enrich_artist(artist) do
      {:ok, enriched} ->
        Logger.info("EnrichArtistLinks: enriched #{inspect(name)}")
        PubSub.broadcast("artist:#{artist.id}", {:artist_enriched, enriched})
        :ok

      {:error, reason} ->
        Logger.error("EnrichArtistLinks: failed to enrich #{inspect(name)}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
