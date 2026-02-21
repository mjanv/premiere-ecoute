defmodule PremiereEcouteWeb.Sessions.OverlayLive do
  @moduledoc """
  OBS streaming overlay LiveView for listening sessions.

  Displays real-time session information with configurable score display modes (player, streamer, viewer, both), playback progress tracking, vote status integration, track summaries with viewer/streamer scores, and presence tracking for active sessions.
  """

  use PremiereEcouteWeb, :live_view

  require Logger

  import PremiereEcouteWeb.Sessions.Overlay

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Presence
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcouteCore.Cache

  @impl true
  def mount(%{"id" => user_id}, _session, socket) do
    user = PremiereEcoute.Accounts.get_user!(user_id)
    listening_session = ListeningSession.get_active_session(user)

    color_primary = Accounts.profile(user, [:widget_settings, :color_primary])
    color_secondary = Accounts.profile(user, [:widget_settings, :color_secondary])

    if connected?(socket) do
      PremiereEcoute.PubSub.subscribe("playback:#{user_id}")
    end

    socket =
      case listening_session do
        nil ->
          socket
          |> assign(:user_id, user_id)
          |> assign(:id, nil)
          |> assign(:score, :streamer)
          |> assign(:percent, 0)
          |> assign(:progress, AsyncResult.loading())
          |> assign(:widget_state, :idle)
          |> assign(:color_primary, color_primary)
          |> assign(:color_secondary, color_secondary)
          |> assign(:listening_session, nil)
          |> assign(:summary, AsyncResult.loading())

        session ->
          if connected?(socket) do
            {:ok, _} = Presence.join(session.user.id)
            PremiereEcoute.PubSub.subscribe("session:#{session.id}")
          end

          _ = PlayerSupervisor.start(session.user.id)

          widget_state =
            case session.user.twitch do
              nil ->
                :closed

              twitch ->
                case Cache.get(:sessions, twitch.user_id) do
                  {:ok, cached_session} when not is_nil(cached_session) -> :open
                  _ -> :closed
                end
            end

          summary_result =
            case Report.get_by(session_id: session.id) do
              nil ->
                AsyncResult.loading()

              report ->
                summary = Enum.find(report.track_summaries, fn s -> s["track_id"] == session.current_track_id end)

                if is_nil(summary) do
                  AsyncResult.ok(%{viewer_score: nil, streamer_score: nil})
                else
                  AsyncResult.ok(summary)
                end
            end

          socket
          |> assign(:user_id, user_id)
          |> assign(:id, session.id)
          |> assign(:score, :streamer)
          |> assign(:percent, 0)
          |> assign(:progress, AsyncResult.loading())
          |> assign(:widget_state, widget_state)
          |> assign(:color_primary, color_primary)
          |> assign(:color_secondary, color_secondary)
          |> assign(:listening_session, session)
          |> assign(:summary, summary_result)
      end

    {:ok, socket}
  end

  @impl true
  def terminate(_reason, %{assigns: %{listening_session: nil}}) do
    :ok
  end

  def terminate(_reason, %{assigns: %{listening_session: session}}) do
    Presence.unjoin(session.user.id)
    :ok
  end

  @impl true
  def handle_params(%{"score" => score}, _url, socket) do
    {:noreply, assign(socket, :score, parse_score(score))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_updated, session}, %{assigns: %{summary: summary}} = socket) do
    socket
    |> assign(:listening_session, session)
    |> assign(:summary, AsyncResult.ok(summary, %{viewer_score: nil, streamer_score: nil}))
    |> then(fn socket -> {:noreply, socket} end)
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
  def handle_info(:vote_open, %{assigns: %{summary: summary}} = socket) do
    socket
    |> assign(:widget_state, :open)
    |> assign(:summary, AsyncResult.ok(summary, %{viewer_score: nil, streamer_score: nil}))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info(:vote_close, %{assigns: %{summary: summary}} = socket) do
    summary =
      if summary.ok? do
        AsyncResult.ok(summary, Map.merge(summary.result, %{viewer_score: nil, streamer_score: nil}))
      else
        summary
      end

    socket
    |> assign(:widget_state, :closed)
    |> assign(:summary, summary)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:session_started, session_id}, %{assigns: %{user_id: user_id}} = socket) do
    session = ListeningSession.get(session_id)
    PremiereEcoute.PubSub.subscribe("session:#{session_id}")
    _ = Presence.join(user_id)
    _ = PlayerSupervisor.start(user_id)

    widget_state =
      case session.user.twitch do
        nil ->
          :closed

        twitch ->
          case Cache.get(:sessions, twitch.user_id) do
            {:ok, cached_session} when not is_nil(cached_session) -> :open
            _ -> :closed
          end
      end

    socket =
      socket
      |> assign(:id, session.id)
      |> assign(:listening_session, session)
      |> assign(:summary, AsyncResult.ok(%{viewer_score: nil, streamer_score: nil}))
      |> assign(:widget_state, widget_state)
      |> assign(:progress, AsyncResult.loading())
      |> assign(:percent, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:session_stopped, %{assigns: %{listening_session: session, user_id: user_id}} = socket)
      when not is_nil(session) do
    PremiereEcoute.PubSub.unsubscribe("session:#{session.id}")
    Presence.unjoin(user_id)

    socket =
      socket
      |> assign(:id, nil)
      |> assign(:listening_session, nil)
      |> assign(:summary, AsyncResult.loading())
      |> assign(:widget_state, :ended)
      |> assign(:progress, AsyncResult.loading())
      |> assign(:percent, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:stop, %{assigns: %{listening_session: session}} = socket) when not is_nil(session) do
    socket =
      socket
      |> assign(:id, nil)
      |> assign(:listening_session, nil)
      |> assign(:summary, AsyncResult.loading())
      |> assign(:widget_state, :ended)
      |> assign(:progress, AsyncResult.loading())
      |> assign(:percent, 0)

    {:noreply, socket}
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
