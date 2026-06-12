defmodule PremiereEcoute.Podcasts.Workers.EpisodeIngestionWorker do
  @moduledoc """
  Processes a freshly-uploaded episode: fetches the audio from storage, validates it is an MP3,
  extracts its duration (pure-Elixir parser) and byte size, and marks the episode `:ready`. On any
  failure the episode is marked `:failed`. Emits `EpisodeProcessed` on success.

  Enqueue after the upload is finalized: `EpisodeIngestionWorker.start(%{id: episode.id})`.
  """

  use PremiereEcouteCore.Worker, queue: :podcasts, max_attempts: 3

  require Logger

  alias PremiereEcoute.Events.EpisodeProcessed
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Audio.Mp3
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Storage
  alias PremiereEcoute.PubSub

  @doc "PubSub topic a show's studio dashboard subscribes to for ingestion updates."
  @spec topic(integer()) :: String.t()
  def topic(show_id), do: "podcast_show:#{show_id}"

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}), do: run(Episode.get(id))

  @spec run(Episode.t() | nil) :: :ok | {:error, term()}
  def run(nil), do: {:error, :not_found}
  def run(%Episode{audio_key: nil}), do: {:error, :no_audio}

  def run(%Episode{audio_key: key} = episode) do
    with {:ok, bytes} <- Storage.fetch(key),
         {:ok, duration} <- Mp3.duration(bytes) do
      byte_size = byte_size(bytes)
      {:ok, ready} = Episode.mark_ready(episode, %{duration_seconds: duration, audio_byte_size: byte_size})

      Store.append(
        %EpisodeProcessed{id: ready.id, duration_seconds: duration, audio_byte_size: byte_size},
        stream: "podcasts_episode"
      )

      PubSub.broadcast(topic(ready.show_id), {:episode_updated, ready.id})
      Logger.info("podcast episode #{ready.id} ingested (#{duration}s, #{byte_size} bytes)")
      :ok
    else
      {:error, reason} ->
        Episode.mark_failed(episode)
        PubSub.broadcast(topic(episode.show_id), {:episode_updated, episode.id})
        Logger.warning("podcast episode #{episode.id} ingestion failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
