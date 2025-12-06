defmodule PremiereEcouteWeb.Twitch.HistoryViewLive do
  @moduledoc """
  Displays the parsed Twitch history data from an uploaded file.

  This LiveView shows the details extracted from a Twitch data export, including username, user ID, request ID, and date range information.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History
  alias PremiereEcoute.Twitch.History.Ads
  alias PremiereEcoute.Twitch.History.Commerce
  alias PremiereEcoute.Twitch.History.Community
  alias PremiereEcoute.Twitch.History.SiteHistory
  alias PremiereEcoute.Twitch.History.TimelineHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = History.file_path(id)

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:periods, %{
      follows: "month",
      messages: "month",
      minutes: "month",
      subscriptions: "month",
      bits: "month",
      ads: "month"
    })
    |> assign_async([:history, :follows, :messages, :minutes, :subscriptions, :bits, :ads], fn ->
      if File.exists?(file_path) do
        {:ok,
         %{
           history: History.read(file_path),
           follows: Community.Follows.read(file_path),
           messages: SiteHistory.ChatMessages.read(file_path),
           minutes: SiteHistory.MinuteWatched.read(file_path),
           subscriptions: Commerce.Subscriptions.read(file_path),
           bits: Commerce.BitsCheered.read(file_path),
           ads: Ads.VideoAdImpression.read(file_path)
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
  def handle_event("change_period", %{"graph" => graph, "period" => period}, %{assigns: %{periods: periods}} = socket) do
    {:noreply, assign(socket, :periods, Map.put(periods, String.to_existing_atom(graph), period))}
  end

  defp graph_data(nil, _periods, _period), do: []

  defp graph_data(follows, %{follows: period}, :follows) do
    {groups, label} = params(period)

    follows
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(follows: Series.n_distinct(channel))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "follows" => row["follows"]} end)
    |> TimelineHelper.fill_missing_periods("follows", period)
  end

  defp graph_data(messages, %{messages: period}, :messages) do
    {groups, label} = params(period)

    messages
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(messages: Series.count(body))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "messages" => row["messages"]} end)
    |> TimelineHelper.fill_missing_periods("messages", period)
  end

  defp graph_data(minutes, %{minutes: period}, :minutes) do
    {groups, label} = params(period)

    minutes
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(minutes: Series.sum(minutes_watched_unadjusted))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "minutes" => row["minutes"]} end)
    |> TimelineHelper.fill_missing_periods("minutes", period)
  end

  defp graph_data(subscriptions, %{subscriptions: period}, :subscriptions) do
    {groups, label} = params(period)

    subscriptions
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(subscriptions: Series.count(channel_login))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "subscriptions" => row["subscriptions"]} end)
    |> TimelineHelper.fill_missing_periods("subscriptions", period)
  end

  defp graph_data(ads, %{ads: period}, :ads) do
    {groups, label} = params(period)

    ads
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(impressions: Series.count(roll_type))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "impressions" => row["impressions"]} end)
    |> TimelineHelper.fill_missing_periods("impressions", period)
  end

  defp graph_data(bits, %{bits: period}, :bits) do
    {groups, label} = params(period)

    bits
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(bits: Series.sum(used_total))
    |> DataFrame.ungroup()
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "bits" => row["bits"]} end)
    |> TimelineHelper.fill_missing_periods("bits", period)
  end

  defp params(period) do
    case period do
      "day" ->
        {[:year, :month, :day],
         fn %{"year" => y, "month" => m, "day" => d} ->
           "#{y}-#{String.pad_leading(to_string(m), 2, "0")}-#{String.pad_leading(to_string(d), 2, "0")}"
         end}

      "week" ->
        {[:year, :week], fn %{"year" => y, "week" => w} -> "#{y}-W#{String.pad_leading(to_string(w), 2, "0")}" end}

      "month" ->
        {[:year, :month], fn %{"year" => y, "month" => m} -> "#{y}-#{String.pad_leading(to_string(m), 2, "0")}" end}

      "year" ->
        {[:year], fn %{"year" => y} -> "#{y}" end}
    end
  end
end
