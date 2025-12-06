defmodule PremiereEcouteWeb.Twitch.History.SubscriptionsLive do
  @moduledoc """
  Displays detailed subscriptions data from a Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History
  alias PremiereEcoute.Twitch.History.Commerce
  alias PremiereEcoute.Twitch.History.TimelineHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = History.file_path(id)

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:selected_period, "month")
    |> assign(:selected_type, "all")
    |> assign_async(:subscriptions, fn ->
      if File.exists?(file_path) do
        subs_df = Commerce.Subscriptions.read(file_path)
        total = DataFrame.n_rows(subs_df)

        total_paid =
          subs_df
          |> DataFrame.filter_with(fn df -> Series.equal(df["is_paid"], true) end)
          |> DataFrame.n_rows()

        total_gift =
          subs_df
          |> DataFrame.filter_with(fn df -> Series.equal(df["is_gift"], true) end)
          |> DataFrame.n_rows()

        total_prime =
          subs_df
          |> DataFrame.filter_with(fn df -> Series.equal(df["is_prime_sub"], true) end)
          |> DataFrame.n_rows()

        {:ok,
         %{
           subscriptions: %{
             total: total,
             total_paid: total_paid,
             total_gift: total_gift,
             total_prime: total_prime,
             df: subs_df
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
  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_type, type)}
  end

  defp stacked_graph_data(subs_df, period) do
    {groups, label} = period_params(period)

    paid_data =
      subs_df
      |> DataFrame.filter_with(fn df -> Series.equal(df["is_paid"], true) end)
      |> DataFrame.group_by(groups)
      |> DataFrame.summarise(count: Series.count(channel_login))
      |> apply_period_sort(period)
      |> DataFrame.to_rows()
      |> Enum.map(fn row -> %{"date" => label.(row), "count" => row["count"], "type" => "Paid"} end)
      |> TimelineHelper.fill_missing_periods("count", period)
      |> Enum.map(&Map.put(&1, "type", "Paid"))

    gift_data =
      subs_df
      |> DataFrame.filter_with(fn df -> Series.equal(df["is_gift"], true) end)
      |> DataFrame.group_by(groups)
      |> DataFrame.summarise(count: Series.count(channel_login))
      |> apply_period_sort(period)
      |> DataFrame.to_rows()
      |> Enum.map(fn row -> %{"date" => label.(row), "count" => row["count"], "type" => "Gift"} end)
      |> TimelineHelper.fill_missing_periods("count", period)
      |> Enum.map(&Map.put(&1, "type", "Gift"))

    prime_data =
      subs_df
      |> DataFrame.filter_with(fn df -> Series.equal(df["is_prime_sub"], true) end)
      |> DataFrame.group_by(groups)
      |> DataFrame.summarise(count: Series.count(channel_login))
      |> apply_period_sort(period)
      |> DataFrame.to_rows()
      |> Enum.map(fn row -> %{"date" => label.(row), "count" => row["count"], "type" => "Prime"} end)
      |> TimelineHelper.fill_missing_periods("count", period)
      |> Enum.map(&Map.put(&1, "type", "Prime"))

    paid_data ++ gift_data ++ prime_data
  end

  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)

  defp period_params(period) do
    case period do
      "month" ->
        {[:year, :month], fn %{"year" => y, "month" => m} -> "#{y}-#{String.pad_leading(to_string(m), 2, "0")}" end}

      "year" ->
        {[:year], fn %{"year" => y} -> "#{y}" end}
    end
  end

  defp get_subscriptions_list(subs_df, type) do
    subs_df
    |> apply_type_filter(type)
    |> DataFrame.sort_by(desc: access_start)
    |> DataFrame.to_rows()
  end

  defp apply_type_filter(df, "all"), do: df

  defp apply_type_filter(df, "paid") do
    DataFrame.filter_with(df, fn df -> Series.equal(df["is_paid"], true) end)
  end

  defp apply_type_filter(df, "gift") do
    DataFrame.filter_with(df, fn df -> Series.equal(df["is_gift"], true) end)
  end

  defp apply_type_filter(df, "prime") do
    DataFrame.filter_with(df, fn df -> Series.equal(df["is_prime_sub"], true) end)
  end

  defp subscription_type(sub) do
    cond do
      sub["is_paid"] == true -> "Paid"
      sub["is_gift"] == true -> "Gift"
      sub["is_prime_sub"] == true -> "Prime"
      true -> "Other"
    end
  end

  defp subscription_type_color(type) do
    case type do
      "Paid" -> "bg-pink-600/10 text-pink-300 border-pink-500/30"
      "Gift" -> "bg-purple-600/10 text-purple-300 border-purple-500/30"
      "Prime" -> "bg-orange-600/10 text-orange-300 border-orange-500/30"
      _ -> "bg-slate-600/10 text-slate-300 border-slate-500/30"
    end
  end
end
