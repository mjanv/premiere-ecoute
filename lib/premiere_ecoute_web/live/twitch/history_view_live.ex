defmodule PremiereEcouteWeb.Twitch.HistoryViewLive do
  @moduledoc """
  Displays the parsed Twitch history data from an uploaded file.

  This LiveView shows the details extracted from a Twitch data export, including username, user ID, request ID, and date range information.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Twitch

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = Path.join("priv/static/uploads", id)

    {:ok,
     socket
     |> assign(:filename, id)
     |> assign(:file_path, file_path)
     |> assign(:follows_period, "month")
     |> assign(:messages_period, "month")
     |> assign(:minutes_period, "month")
     |> assign(:subscriptions_period, "month")
     |> assign_async([:history, :follows, :messages, :minutes, :subscriptions], fn ->
       history =
         if File.exists?(file_path) do
           Twitch.History.read(file_path)
         else
           nil
         end

       follows =
         if File.exists?(file_path) do
           try do
             Twitch.History.Community.Follows.read(file_path)
           rescue
             _ -> nil
           end
         else
           nil
         end

       messages =
         if File.exists?(file_path) do
           try do
             Twitch.History.SiteHistory.ChatMessages.read(file_path)
           rescue
             _ -> nil
           end
         else
           nil
         end

       minutes =
         if File.exists?(file_path) do
           try do
             Twitch.History.SiteHistory.MinuteWatched.read(file_path)
           rescue
             _ -> nil
           end
         else
           nil
         end

       subscriptions =
         if File.exists?(file_path) do
           try do
             Twitch.History.Commerce.Subscriptions.read(file_path)
           rescue
             _ -> nil
           end
         else
           nil
         end

       {:ok,
        %{
          history: history,
          follows: follows,
          messages: messages,
          minutes: minutes,
          subscriptions: subscriptions
        }}
     end)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_follows_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :follows_period, period)}
  end

  @impl true
  def handle_event("change_messages_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :messages_period, period)}
  end

  @impl true
  def handle_event("change_minutes_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :minutes_period, period)}
  end

  @impl true
  def handle_event("change_subscriptions_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :subscriptions_period, period)}
  end

  # AIDEV-NOTE: helper function for template date formatting
  def format_date(datetime) do
    datetime
    |> to_string()
  end

  # AIDEV-NOTE: prepare follows DataFrame for VegaLite graph - groups by selected period and counts follows
  def prepare_follows_graph_data(nil, _period), do: []

  def prepare_follows_graph_data(follows_df, period) do
    require Explorer.DataFrame, as: DataFrame
    alias Explorer.Series

    {group_by_cols, sort_fn, format_fn} =
      case period do
        "week" ->
          {[:year, :week], fn %{"year" => year, "week" => week} -> {year, week} end,
           fn %{"year" => year, "week" => week} ->
             week_str = if week < 10, do: "0#{week}", else: "#{week}"
             "#{year}-W#{week_str}"
           end}

        "month" ->
          {[:year, :month], fn %{"year" => year, "month" => month} -> {year, month} end,
           fn %{"year" => year, "month" => month} ->
             month_str = if month < 10, do: "0#{month}", else: "#{month}"
             "#{year}-#{month_str}"
           end}

        "year" ->
          {[:year], fn %{"year" => year} -> year end, fn %{"year" => year} -> "#{year}" end}
      end

    follows_df
    |> DataFrame.group_by(group_by_cols)
    |> DataFrame.summarise(follows: Series.n_distinct(channel))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.sort_by(sort_fn)
    |> Enum.map(fn row ->
      %{"date" => format_fn.(row), "follows" => row["follows"]}
    end)
  end

  # AIDEV-NOTE: prepare messages DataFrame for VegaLite graph - groups by selected period and counts messages
  def prepare_messages_graph_data(nil, _period), do: []

  def prepare_messages_graph_data(messages_df, period) do
    require Explorer.DataFrame, as: DataFrame
    alias Explorer.Series

    {group_by_cols, sort_fn, format_fn} =
      case period do
        "day" ->
          {[:year, :day], fn %{"year" => year, "day" => day} -> {year, day} end,
           fn %{"year" => year, "day" => day} ->
             day_str = if day < 10, do: "00#{day}", else: if(day < 100, do: "0#{day}", else: "#{day}")
             "#{year}-#{day_str}"
           end}

        "week" ->
          {[:year, :week], fn %{"year" => year, "week" => week} -> {year, week} end,
           fn %{"year" => year, "week" => week} ->
             week_str = if week < 10, do: "0#{week}", else: "#{week}"
             "#{year}-W#{week_str}"
           end}

        "month" ->
          {[:year, :month], fn %{"year" => year, "month" => month} -> {year, month} end,
           fn %{"year" => year, "month" => month} ->
             month_str = if month < 10, do: "0#{month}", else: "#{month}"
             "#{year}-#{month_str}"
           end}

        "year" ->
          {[:year], fn %{"year" => year} -> year end, fn %{"year" => year} -> "#{year}" end}
      end

    messages_df
    |> DataFrame.group_by(group_by_cols)
    |> DataFrame.summarise(messages: Series.count(body))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.sort_by(sort_fn)
    |> Enum.map(fn row ->
      %{"date" => format_fn.(row), "messages" => row["messages"]}
    end)
  end

  # AIDEV-NOTE: prepare minutes watched DataFrame for VegaLite graph - groups by selected period and sums minutes
  def prepare_minutes_graph_data(nil, _period), do: []

  def prepare_minutes_graph_data(minutes_df, period) do
    require Explorer.DataFrame, as: DataFrame
    alias Explorer.Series

    # Extract year, month, week from day column
    minutes_with_time =
      minutes_df
      |> DataFrame.mutate_with(
        &[
          year: Series.year(&1["day"]),
          month: Series.month(&1["day"]),
          week: Series.week_of_year(&1["day"]),
          day_of_year: Series.day_of_year(&1["day"])
        ]
      )

    {group_by_cols, sort_fn, format_fn} =
      case period do
        "day" ->
          {[:year, :day_of_year], fn %{"year" => year, "day_of_year" => day} -> {year, day} end,
           fn %{"year" => year, "day_of_year" => day} ->
             day_str = if day < 10, do: "00#{day}", else: if(day < 100, do: "0#{day}", else: "#{day}")
             "#{year}-#{day_str}"
           end}

        "week" ->
          {[:year, :week], fn %{"year" => year, "week" => week} -> {year, week} end,
           fn %{"year" => year, "week" => week} ->
             week_str = if week < 10, do: "0#{week}", else: "#{week}"
             "#{year}-W#{week_str}"
           end}

        "month" ->
          {[:year, :month], fn %{"year" => year, "month" => month} -> {year, month} end,
           fn %{"year" => year, "month" => month} ->
             month_str = if month < 10, do: "0#{month}", else: "#{month}"
             "#{year}-#{month_str}"
           end}

        "year" ->
          {[:year], fn %{"year" => year} -> year end, fn %{"year" => year} -> "#{year}" end}
      end

    minutes_with_time
    |> DataFrame.group_by(group_by_cols)
    |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.sort_by(sort_fn)
    |> Enum.map(fn row ->
      %{"date" => format_fn.(row), "minutes" => row["minutes"]}
    end)
  end

  # AIDEV-NOTE: prepare subscriptions DataFrame for VegaLite graph - groups by selected period and counts subscriptions
  def prepare_subscriptions_graph_data(nil, _period), do: []

  def prepare_subscriptions_graph_data(subscriptions_df, period) do
    require Explorer.DataFrame, as: DataFrame
    alias Explorer.Series

    {group_by_cols, sort_fn, format_fn} =
      case period do
        "month" ->
          {[:year, :month], fn %{"year" => year, "month" => month} -> {year, month} end,
           fn %{"year" => year, "month" => month} ->
             month_str = if month < 10, do: "0#{month}", else: "#{month}"
             "#{year}-#{month_str}"
           end}

        "year" ->
          {[:year], fn %{"year" => year} -> year end, fn %{"year" => year} -> "#{year}" end}
      end

    subscriptions_df
    |> DataFrame.group_by(group_by_cols)
    |> DataFrame.summarise(subscriptions: Series.count(channel_login))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.sort_by(sort_fn)
    |> Enum.map(fn row ->
      %{"date" => format_fn.(row), "subscriptions" => row["subscriptions"]}
    end)
  end
end
