defmodule PremiereEcouteWeb.Twitch.History.BitsLive do
  @moduledoc """
  Displays detailed bits cheered data from a Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History.Commerce
  alias PremiereEcoute.Twitch.History.TimelineHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = Path.join("priv/static/uploads", "#{id}.zip")

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:selected_period, "month")
    |> assign_async(:bits, fn ->
      if File.exists?(file_path) do
        bits_df = Commerce.BitsCheered.read(file_path)
        total = DataFrame.n_rows(bits_df)

        total_bits =
          bits_df
          |> DataFrame.pull("used_total")
          |> Series.sum()

        {:ok,
         %{
           bits: %{
             total: total,
             total_bits: total_bits,
             df: bits_df
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

  defp graph_data(bits_df, period) do
    {groups, label} = period_params(period)

    bits_df
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(count: Series.count(channel_login), bits: Series.sum(used_total))
    |> apply_period_sort(period)
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "count" => row["count"], "bits" => row["bits"]} end)
    |> TimelineHelper.fill_missing_periods("bits", period)
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

  defp get_bits_list(bits_df) do
    bits_df
    |> DataFrame.sort_by(desc: time)
    |> DataFrame.to_rows()
  end
end
