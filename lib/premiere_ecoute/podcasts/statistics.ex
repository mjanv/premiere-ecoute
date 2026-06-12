defmodule PremiereEcoute.Podcasts.Statistics do
  @moduledoc """
  Streamer-facing podcast analytics.

  Sourced from the **Postgres-backed event store** (`event_store.events`), so these numbers are
  durable indefinitely — unlike Prometheus, which only retains ~14 days. Built on `EpisodeDownloaded`
  events (stream `podcast_download-<episode_id>`), each tagged by source (`:web` vs `:feed`), via
  `Analytics.aggregate_events/3`.
  """

  alias PremiereEcoute.Analytics
  alias PremiereEcoute.Events.EpisodeDownloaded
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show

  @type breakdown :: %{total: non_neg_integer(), web: non_neg_integer(), feed: non_neg_integer()}

  @doc "Download totals for one episode, split by source."
  @spec episode_downloads(Episode.t()) :: breakdown()
  def episode_downloads(%Episode{id: id}), do: breakdown([stream(id)], [])

  @doc "Download totals across all of a show's episodes, split by source."
  @spec show_downloads(Show.t()) :: breakdown()
  def show_downloads(%Show{} = show), do: breakdown(streams(show), [])

  @doc "Total downloads for a show within the last `days` days."
  @spec show_downloads_last(Show.t(), pos_integer()) :: non_neg_integer()
  def show_downloads_last(%Show{} = show, days) do
    from = DateTime.add(DateTime.utc_now(), -days, :day)
    breakdown(streams(show), from: from).total
  end

  @doc "Episode downloads bucketed by a time unit (`:day`, `:week`, …) for charts."
  @spec episode_downloads_over_time(Episode.t(), Analytics.Events.unit(), keyword()) :: [map()]
  def episode_downloads_over_time(%Episode{id: id}, unit, opts \\ []) do
    Analytics.aggregate_events(EpisodeDownloaded, unit, Keyword.merge([stream: stream(id)], opts))
  end

  defp breakdown([], _opts), do: %{total: 0, web: 0, feed: 0}

  defp breakdown(streams, opts) do
    EpisodeDownloaded
    |> Analytics.aggregate_events(:year, Keyword.merge([stream: streams, fields: [:source]], opts))
    |> Enum.reduce(%{total: 0, web: 0, feed: 0}, fn %{count: count} = row, acc ->
      acc
      |> Map.update!(:total, &(&1 + count))
      |> add_source(Map.get(row, :source), count)
    end)
  end

  defp add_source(acc, "web", count), do: Map.update!(acc, :web, &(&1 + count))
  defp add_source(acc, "feed", count), do: Map.update!(acc, :feed, &(&1 + count))
  defp add_source(acc, _other, _count), do: acc

  defp stream(id), do: "podcast_download-#{id}"
  defp streams(%Show{} = show), do: show |> Episode.all_for_show() |> Enum.map(&stream(&1.id))
end
