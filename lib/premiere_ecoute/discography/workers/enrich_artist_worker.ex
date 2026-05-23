defmodule PremiereEcoute.Discography.Workers.EnrichArtistWorker do
  @moduledoc "Oban worker that fills external links and provider IDs for a specific or random unenriched artist."

  use PremiereEcouteCore.Worker, queue: :discography, max_attempts: 3

  require Logger

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichArtist
  alias PremiereEcoute.PubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}), do: run(Artist.get(id))
  def perform(%Oban.Job{}), do: run(Artist.random())

  def run(nil), do: {:error, :not_found}

  def run(%Artist{} = artist) do
    case EnrichArtist.enrich_artist(artist) do
      {:ok, artist} ->
        PubSub.broadcast("artist:#{artist.id}", {:artist_enriched, artist})
        Logger.info("artist #{artist.id} (#{artist.name}) enriched")
        :ok

      {:error, reason} ->
        Logger.warning("artist #{artist.id} (#{artist.name}) failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
