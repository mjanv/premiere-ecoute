defmodule PremiereEcouteWeb.Twitch.History.BitsLive do
  @moduledoc """
  Displays detailed bits cheered data from a Twitch history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcoute.Twitch.History
  alias PremiereEcoute.Twitch.History.Commerce
  alias PremiereEcoute.Twitch.History.TimelineHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket
    |> assign(:id, id)
    |> assign(:periods, %{bits: "month"})
    |> assign_async(:bits, fn ->
      bits = Commerce.BitsCheered.read(History.file_path(id))

      bits = %{
        df: bits,
        stats: %{
          total: DataFrame.n_rows(bits),
          total_bits: Series.sum(DataFrame.pull(bits, "used_total"))
        }
      }

      {:ok, %{bits: bits}}
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

  defp graph_data(bits_df, period) do
    {groups, label} = TimelineHelper.period_params(period)

    bits_df
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(count: Series.count(used_total), bits: Series.sum(used_total))
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> %{"date" => label.(row), "count" => row["count"], "bits" => row["bits"]} end)
    |> TimelineHelper.fill_missing_periods("bits", period)
  end
end
