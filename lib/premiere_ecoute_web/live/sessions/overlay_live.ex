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

    case Report.get_by(session_id: id) do
      nil -> {:ok, assign(socket, :summary, AsyncResult.loading())}
      report -> {:ok, assign(socket, :summary, AsyncResult.ok(report.session_summary))}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_summary, session_summary}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, :summary, AsyncResult.ok(assigns.summary, session_summary))}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end
end
