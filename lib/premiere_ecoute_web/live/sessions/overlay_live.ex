defmodule PremiereEcouteWeb.Sessions.OverlayLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{id}")
    end

    socket =
      socket
      |> assign(:id, id)
      |> assign(:score, :streamer)
      |> assign(:percent, 0)
      |> assign(:progress, AsyncResult.loading())
      |> assign(:open_vote, true)

    session = ListeningSession.get(id)

    case Report.get_by(session_id: id) do
      nil ->
        {:ok, assign(socket, :summary, AsyncResult.loading())}

      report ->
        summary = Enum.find(report.track_summaries, fn s -> s["track_id"] == session.current_track_id end)
        {:ok, assign(socket, :summary, AsyncResult.ok(summary))}
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
  def handle_info({:progress, %{"duration_ms" => duration, "progress_ms" => progress} = p}, %{assigns: assigns} = socket) do
    socket
    |> assign(:percent, round(100 * progress / duration))
    |> assign(:progress, AsyncResult.ok(assigns.progress, p))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:vote_open, socket) do
    socket
    |> assign(:open_vote, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:vote_close, %{assigns: %{summary: summary}} = socket) do
    socket
    |> assign(:open_vote, false)
    |> assign(:summary, AsyncResult.ok(summary, Map.merge(summary.result, %{"viewer_score" => 0.0, "streamer_score" => 0.0})))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp parse_score("viewer"), do: :viewer
  defp parse_score("streamer"), do: :streamer
  defp parse_score("viewer streamer"), do: :both
  defp parse_score(_), do: :player

  defp overlay_width(:player), do: 480 * 2.5
  defp overlay_width(:both), do: 480
  defp overlay_width(_), do: 240

  defp overlay_height(_), do: 240

  defp score_value(summary, :viewer), do: summary["viewer_score"] || summary.viewer_score
  defp score_value(summary, :streamer), do: summary["streamer_score"] || summary.streamer_score
  defp score_label(:viewer), do: "Chat"
  defp score_label(:streamer), do: "Streamer"
end
