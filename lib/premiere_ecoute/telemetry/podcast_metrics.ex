defmodule PremiereEcoute.Telemetry.PodcastMetrics do
  @moduledoc """
  PromEx plugin for podcast operational metrics (Prometheus/Grafana).

  These are system/health signals — ingestion throughput & failures, RSS feed and audio request
  rates — where ~14-day Prometheus retention is fine. Durable, streamer-facing analytics (download
  counts over time) live in the Postgres event store instead, see `PremiereEcoute.Podcasts.Statistics`.
  """

  use PromEx.Plugin

  @ingestion [:premiere_ecoute, :podcasts, :ingestion]
  @feed [:premiere_ecoute, :podcasts, :feed]
  @audio [:premiere_ecoute, :podcasts, :audio]

  @doc "Records an episode ingestion run (result + duration in ms)."
  @spec ingestion(:ok | :failed, non_neg_integer()) :: :ok
  def ingestion(result, duration_ms), do: :telemetry.execute(@ingestion, %{duration: duration_ms}, %{result: result})

  @doc "Records an RSS feed request by response status."
  @spec feed(non_neg_integer()) :: :ok
  def feed(status), do: :telemetry.execute(@feed, %{}, %{status: status})

  @doc "Records an audio request by source (`:web` or `:feed`)."
  @spec audio(atom()) :: :ok
  def audio(source), do: :telemetry.execute(@audio, %{}, %{source: source})

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :premiere_ecoute_podcasts_ingestion,
        [
          counter(@ingestion ++ [:count],
            event_name: @ingestion,
            description: "Podcast episode ingestion runs",
            tags: [:result]
          ),
          distribution(@ingestion ++ [:duration, :milliseconds],
            event_name: @ingestion,
            measurement: :duration,
            description: "Podcast episode ingestion duration",
            reporter_options: [buckets: [100, 500, 1_000, 5_000, 15_000, 60_000]],
            tags: [:result]
          )
        ]
      ),
      Event.build(
        :premiere_ecoute_podcasts_feed,
        [
          counter(@feed ++ [:count],
            event_name: @feed,
            description: "Podcast RSS feed requests",
            tags: [:status]
          )
        ]
      ),
      Event.build(
        :premiere_ecoute_podcasts_audio,
        [
          counter(@audio ++ [:count],
            event_name: @audio,
            description: "Podcast audio requests",
            tags: [:source]
          )
        ]
      )
    ]
  end
end
