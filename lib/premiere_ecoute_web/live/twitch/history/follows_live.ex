defmodule PremiereEcouteWeb.Twitch.History.FollowsLive do
  @moduledoc """
  Displays detailed follows data from a Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History.Community
  alias PremiereEcoute.Twitch.History.SiteHistory

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = Path.join("priv/static/uploads", "#{id}.zip")

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:search, "")
    |> assign(:sort_by, :time)
    |> assign(:sort_order, :desc)
    |> assign(:selected_channel, nil)
    |> assign_async([:follows, :minutes, :messages], fn ->
      if File.exists?(file_path) do
        follows_df =
          file_path
          |> Community.Follows.read()
          |> DataFrame.sort_by(desc: time)

        minutes_df = SiteHistory.MinuteWatched.read(file_path)
        messages_df = SiteHistory.ChatMessages.read(file_path)

        total = DataFrame.n_rows(follows_df)

        {:ok, %{follows: %{total: total, df: follows_df}, minutes: minutes_df, messages: messages_df}}
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
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    column_atom = String.to_existing_atom(column)

    sort_order =
      if socket.assigns.sort_by == column_atom do
        toggle_sort_order(socket.assigns.sort_order)
      else
        :asc
      end

    {:noreply, socket |> assign(:sort_by, column_atom) |> assign(:sort_order, sort_order)}
  end

  @impl true
  def handle_event("select_channel", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, :selected_channel, channel)}
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp get_follows_list(df, search, sort_by, sort_order) do
    df
    |> apply_sort(sort_by, sort_order)
    |> DataFrame.to_rows()
    |> apply_search_filter(search)
  end

  defp apply_sort(df, :channel, :asc), do: DataFrame.sort_by(df, asc: channel)
  defp apply_sort(df, :channel, :desc), do: DataFrame.sort_by(df, desc: channel)
  defp apply_sort(df, :time, :asc), do: DataFrame.sort_by(df, asc: time)
  defp apply_sort(df, :time, :desc), do: DataFrame.sort_by(df, desc: time)

  defp apply_search_filter(rows, search) when search == "" or is_nil(search), do: rows

  defp apply_search_filter(rows, search) do
    search_lower = String.downcase(search)

    Enum.filter(rows, fn follow ->
      String.contains?(String.downcase(follow["channel"]), search_lower)
    end)
  end

  defp get_channel_follow_date(follows_df, channel) do
    follows_df
    |> DataFrame.filter_with(fn df -> Series.equal(df["channel"], channel) end)
    |> DataFrame.pull("time")
    |> Series.first()
  end

  defp get_first_streams(minutes_df, channel) do
    minutes_df
    |> DataFrame.filter_with(fn df -> Series.equal(df["channel_name"], channel) end)
    |> DataFrame.sort_by(asc: year, asc: month, asc: day)
    |> DataFrame.select([
      "channel_name",
      "game_name",
      "minutes_watched_unadjusted",
      "year",
      "month",
      "day"
    ])
    |> DataFrame.head(3)
    |> DataFrame.to_rows()
  end

  defp get_first_messages(messages_df, channel) do
    messages_df
    |> DataFrame.filter_with(fn df -> Series.equal(df["channel"], channel) end)
    |> DataFrame.sort_by(asc: time)
    |> DataFrame.select(["channel", "body", "time"])
    |> DataFrame.head(5)
    |> DataFrame.to_rows()
  end
end
