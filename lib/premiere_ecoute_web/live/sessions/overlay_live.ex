defmodule PremiereEcouteWeb.Sessions.OverlayLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions.Scores.Report

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{id}")
    end

    socket =
      socket
      # Default score mode
      |> assign(:score, :streamer)

    case Report.get_by(session_id: id) do
      nil -> {:ok, assign(socket, :summary, AsyncResult.loading())}
      report -> {:ok, assign(socket, :summary, AsyncResult.ok(report.session_summary))}
    end
  end

  @impl true
  def handle_params(%{"score" => score}, _url, socket) do
    {:noreply, assign(socket, :score, parse_score(score))}
  end

  @impl true
  def handle_info({:session_summary, session_summary}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, :summary, AsyncResult.ok(assigns.summary, session_summary))}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp parse_score("viewer"), do: :viewer
  defp parse_score("streamer"), do: :streamer
  defp parse_score("viewer streamer"), do: :both
  defp parse_score(_), do: :streamer

  defp get_overlay_width(:both), do: 160
  defp get_overlay_width(_), do: 120

  defp score_value(summary, :viewer), do: summary.viewer_score
  defp score_value(summary, :streamer), do: summary.streamer_score
  defp score_label(:viewer), do: "VIEWER"
  defp score_label(:streamer), do: "STREAMER"
end
