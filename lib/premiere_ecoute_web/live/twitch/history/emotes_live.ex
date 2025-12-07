defmodule PremiereEcouteWeb.Twitch.History.EmotesLive do
  @moduledoc """
  Displays emote usage data extracted from Twitch chat messages.

  Features:
  - Filter by emote prefix (e.g., "angled" to see all angledX emotes)
  - Filter by specific emote name (e.g., "angledPepog")
  - View usage over time by period (day, week, month, year)
  - See top emotes by usage count
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame
  alias Explorer.Series
  alias PremiereEcoute.Twitch.History
  alias PremiereEcoute.Twitch.History.SiteHistory
  alias PremiereEcoute.Twitch.History.TimelineHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = History.file_path(id)

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:selected_period, "month")
    |> assign(:filter_text, "")
    |> assign(:filter_mode, "all")
    |> assign_async([:emotes_data], fn ->
      if File.exists?(file_path) do
        emotes_df = SiteHistory.Emotes.read(file_path)

        total = DataFrame.n_rows(emotes_df)

        top_emotes =
          emotes_df
          |> SiteHistory.Emotes.group_by_emote()
          |> DataFrame.to_rows()

        {:ok,
         %{
           emotes_data: %{
             total: total,
             top_emotes: top_emotes,
             df: emotes_df
           }
         }}
      else
        {:error, "No file"}
      end
    end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  @impl true
  def handle_event("update_filter", %{"filter" => filter_text}, socket) do
    filter_mode = detect_filter_mode(filter_text)
    {:noreply, socket |> assign(:filter_text, filter_text) |> assign(:filter_mode, filter_mode)}
  end

  @impl true
  def handle_event("clear_filter", _params, socket) do
    {:noreply, socket |> assign(:filter_text, "") |> assign(:filter_mode, "all")}
  end

  # Detect if the filter text looks like a full emote name or a prefix
  # Heuristic: if it contains uppercase letters in the middle/end, likely a full emote name
  defp detect_filter_mode(""), do: "all"

  defp detect_filter_mode(text) do
    # If text has uppercase after the first character, treat as specific emote
    # Otherwise, treat as prefix
    if String.slice(text, 1..-1//1) =~ ~r/[A-Z]/ do
      "emote"
    else
      "prefix"
    end
  end

  defp apply_filter(df, "", _mode), do: df

  defp apply_filter(df, filter_text, "prefix") do
    SiteHistory.Emotes.group_by_prefix(df, filter_text)
  end

  defp apply_filter(df, filter_text, "emote") do
    SiteHistory.Emotes.group_by_emote_name(df, filter_text)
  end

  defp apply_filter(df, _filter_text, "all"), do: df

  defp graph_data(df, period, filter_text, filter_mode) do
    {groups, label} = TimelineHelper.period_params(period)

    df
    |> apply_filter(filter_text, filter_mode)
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(count: Series.count(emote))
    |> apply_period_sort(period)
    |> DataFrame.to_rows()
    |> Enum.map(fn row ->
      %{
        "date" => label.(row),
        "count" => row["count"]
      }
    end)
    |> TimelineHelper.fill_missing_periods("count", period)
  end

  defp filtered_emotes_list(df, filter_text, filter_mode) do
    df
    |> apply_filter(filter_text, filter_mode)
    |> DataFrame.select(["time", "channel", "emote", "body"])
    |> DataFrame.sort_by(desc: time)
    |> DataFrame.head(100)
    |> DataFrame.to_rows()
  end

  defp filtered_stats(df, filter_text, filter_mode) do
    filtered_df = apply_filter(df, filter_text, filter_mode)

    %{
      total: DataFrame.n_rows(filtered_df),
      unique_emotes:
        filtered_df
        |> DataFrame.select(["emote"])
        |> DataFrame.distinct()
        |> DataFrame.n_rows()
    }
  end

  defp apply_period_sort(df, "day"),
    do: DataFrame.sort_by(df, asc: year, asc: month, asc: day)

  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)

  defp format_datetime(datetime) when is_struct(datetime, NaiveDateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_datetime(_), do: ""
end
