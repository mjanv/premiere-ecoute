defmodule PremiereEcouteWeb.Twitch.History.MessagesLive do
  @moduledoc """
  Displays detailed chat messages data from a Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = Path.join("priv/static/uploads", id)

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:selected_channel, nil)
    |> assign(:selected_period, "month")
    |> assign_async(:messages, fn ->
      if File.exists?(file_path) do
        messages_df = History.SiteHistory.ChatMessages.read(file_path)
        total = DataFrame.n_rows(messages_df)

        messages_by_channel =
          messages_df
          |> History.SiteHistory.ChatMessages.group_channel()
          |> DataFrame.filter_with(fn df -> Series.greater(df["messages"], 0) end)
          |> DataFrame.sort_by(desc: messages)
          |> DataFrame.to_rows()

        {:ok, %{messages: %{total: total, by_channel: messages_by_channel, df: messages_df}}}
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
  def handle_event("select_channel", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, :selected_channel, channel)}
  end

  @impl true
  def handle_event("select_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :selected_period, period)}
  end

  defp graph_data(by_channel) do
    Enum.map(by_channel, fn row ->
      %{"channel" => row["channel"], "messages" => row["messages"]}
    end)
  end

  defp channel_timeline_data(nil, _period, _df), do: []

  defp channel_timeline_data(channel, period, messages_df) do
    {groups, label} = period_params(period)

    messages_df
    |> DataFrame.filter_with(fn df -> Series.equal(df["channel"], channel) end)
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(messages: Series.count(body))
    |> apply_period_sort(period)
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "messages" => row["messages"]} end)
  end

  defp apply_period_sort(df, "day"), do: DataFrame.sort_by(df, asc: year, asc: month, asc: day)
  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)

  defp period_params(period) do
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
