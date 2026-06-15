defmodule PremiereEcoute.Podcasts.Statistics do
  @moduledoc """
  Streamer-facing podcast analytics.

  Sourced from the **Postgres-backed event store** (`event_store.events`), so these numbers are
  durable indefinitely — unlike Prometheus, which only retains ~14 days. Built on `PodcastEpisodeDownloaded`
  events (stream `podcast_download-<episode_id>`), each tagged by source (`:web` vs `:feed`), via
  `Analytics.aggregate_events/3`.
  """

  alias PremiereEcoute.Analytics
  alias PremiereEcoute.Events.PodcastEpisodeDownloaded
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Repo

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
    Analytics.aggregate_events(PodcastEpisodeDownloaded, unit, Keyword.merge([stream: stream(id)], opts))
  end

  @doc "A show's downloads bucketed by a time unit (pass `from:`/`to:`/`fill_gaps: true` for charts)."
  @spec show_downloads_over_time(Show.t(), Analytics.Events.unit(), keyword()) :: [map()]
  def show_downloads_over_time(%Show{} = show, unit, opts \\ []) do
    case streams(show) do
      [] -> []
      streams -> Analytics.aggregate_events(PodcastEpisodeDownloaded, unit, Keyword.merge([stream: streams], opts))
    end
  end

  @doc """
  Unique listeners (IAB-style): distinct `ip` + `user_agent` fingerprints across the downloads of
  an episode or a whole show. Approximates audience size, deduping replays and range requests.
  """
  @spec unique_listeners(Episode.t() | Show.t()) :: non_neg_integer()
  def unique_listeners(%Episode{id: id}), do: distinct_listeners([stream(id)])
  def unique_listeners(%Show{} = show), do: distinct_listeners(streams(show))

  defp distinct_listeners([]), do: 0

  defp distinct_listeners(streams) do
    # COUNT(DISTINCT ip|user_agent) over the episodes' download streams. event_type and stream ids
    # are internal (module name / integer-derived), so parameterized values carry no injection risk.
    sql = """
    SELECT COUNT(DISTINCT COALESCE(e.data->>'ip', '') || '|' || COALESCE(e.data->>'user_agent', ''))
    FROM event_store.events e
    JOIN event_store.stream_events se ON se.event_id = e.event_id
    JOIN event_store.streams s ON s.stream_id = se.stream_id
    WHERE e.event_type = $1 AND s.stream_uuid = ANY($2)
    """

    %{rows: [[count]]} = Repo.query!(sql, [Atom.to_string(PodcastEpisodeDownloaded), streams])
    count
  end

  defp breakdown([], _opts), do: %{total: 0, web: 0, feed: 0}

  defp breakdown(streams, opts) do
    PodcastEpisodeDownloaded
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
