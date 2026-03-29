defmodule PremiereEcoute.Discography.Workers.EnrichTrackWorker do
  @moduledoc "Oban worker that fills external links for a specific track."

  use PremiereEcouteCore.Worker, queue: :discography, max_attempts: 3

  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Services.EnrichTrack
  alias PremiereEcoute.PubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    run(Track.get(id))
  end

  def run(nil), do: {:error, :not_found}

  def run(%Track{} = track) do
    case EnrichTrack.enrich_track(track) do
      {:ok, track} ->
        PubSub.broadcast("track:#{track.id}", {:track_enriched, track})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
