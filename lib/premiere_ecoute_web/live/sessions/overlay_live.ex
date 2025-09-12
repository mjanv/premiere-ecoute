defmodule PremiereEcouteWeb.Sessions.OverlayLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  import PremiereEcouteWeb.Sessions.Overlay

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Presence
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    session = ListeningSession.get(id)

    if connected?(socket) do
      {:ok, _} = Presence.join(session.user.id)

      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{session.id}")
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{session.user.id}")
    end

    {:ok, _} = PlayerSupervisor.start(session.user.id)

    socket =
      socket
      |> assign(:id, id)
      |> assign(:score, :streamer)
      |> assign(:percent, 0)
      |> assign(:progress, AsyncResult.loading())
      |> assign(:open_vote, true)
      |> assign(:listening_session, session)

    case Report.get_by(session_id: id) do
      nil ->
        {:ok, assign(socket, :summary, AsyncResult.loading())}

      report ->
        summary = Enum.find(report.track_summaries, fn s -> s["track_id"] == session.current_track_id end)

        if is_nil(summary) do
          {:ok, assign(socket, :summary, AsyncResult.loading())}
        else
          {:ok, assign(socket, :summary, AsyncResult.ok(summary))}
        end
    end
  end

  @impl true
  def terminate(_reason, %{assigns: assigns}) do
    Presence.unjoin(assigns.listening_session.user.id)
    :ok
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
  def handle_info({:player, :no_device, _state}, socket) do
    socket
    |> assign(:progress, AsyncResult.loading())
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:player, _event, state}, %{assigns: assigns} = socket) do
    socket
    |> assign(:percent, round(100 * state["progress_ms"] / state["item"]["duration_ms"]))
    |> assign(:progress, AsyncResult.ok(assigns.progress, state))
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
    summary =
      if summary.ok? do
        AsyncResult.ok(summary, Map.merge(summary.result, %{"viewer_score" => 0.0, "streamer_score" => 0.0}))
      else
        summary
      end

    socket
    |> assign(:open_vote, false)
    |> assign(:summary, summary)
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
end
