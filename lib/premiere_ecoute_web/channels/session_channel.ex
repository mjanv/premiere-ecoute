defmodule PremiereEcouteWeb.SessionChannel do
  @moduledoc """
  Phoenix Channel for individual listening sessions.

  Handles session:* channel joins with session ID assignment, pushes retrospective report summary on join, and broadcasts real-time session updates including score summaries and track navigation events.
  """

  use PremiereEcouteWeb, :channel

  alias PremiereEcoute.Sessions.Retrospective.Report

  @impl true
  def join("session:" <> id, _payload, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :session_id, id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    case Report.get_by(session_id: socket.assigns.session_id) do
      nil -> :ok
      report -> push(socket, "session_summary", report.session_summary)
    end

    {:noreply, socket}
  end

  def handle_info({:session_summary, %{viewer_score: viewer_score}}, socket) do
    push(socket, "session_summary", %{"viewer_score" => viewer_score})
    {:noreply, socket}
  end

  def handle_info({:next_track, track}, socket) do
    push(socket, "track", track)
    {:noreply, socket}
  end

  def handle_info({:previous_track, track}, socket) do
    push(socket, "track", track)
    {:noreply, socket}
  end
end
