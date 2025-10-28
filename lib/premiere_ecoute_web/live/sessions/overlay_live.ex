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
  def mount(%{"id" => user_id}, _session, socket) do
    user = PremiereEcoute.Accounts.get_user!(user_id)
    listening_session = ListeningSession.get_active_session(user)

    socket =
      case listening_session do
        nil ->
          socket
          |> assign(:id, nil)
          |> assign(:score, :streamer)
          |> assign(:percent, 0)
          |> assign(:progress, AsyncResult.loading())
          |> assign(:open_vote, false)
          |> assign(:listening_session, nil)
          |> assign(:summary, AsyncResult.loading())

        session ->
          if connected?(socket) do
            {:ok, _} = Presence.join(session.user.id)
            PremiereEcoute.PubSub.subscribe(["session:#{session.id}", "playback:#{session.user.id}"])
          end

          _ = PlayerSupervisor.start(session.user.id)

          summary_result =
            case Report.get_by(session_id: session.id) do
              nil ->
                AsyncResult.loading()

              report ->
                summary = Enum.find(report.track_summaries, fn s -> s["track_id"] == session.current_track_id end)

                if is_nil(summary) do
                  AsyncResult.loading()
                else
                  AsyncResult.ok(summary)
                end
            end

          socket
          |> assign(:id, session.id)
          |> assign(:score, :streamer)
          |> assign(:percent, 0)
          |> assign(:progress, AsyncResult.loading())
          |> assign(:open_vote, true)
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
    IO.inspect("PARAMS!")
    IO.inspect(socket.assigns.listening_session.id, label: "params")
    {:noreply, assign(socket, :score, parse_score(score))}
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
  def handle_info(:stop, %{assigns: %{listening_session: session}} = socket) when not is_nil(session) do
    socket =
      socket
      |> assign(:id, nil)
      |> assign(:listening_session, nil)
      |> assign(:summary, AsyncResult.loading())
      |> assign(:open_vote, false)
      |> assign(:progress, AsyncResult.loading())
      |> assign(:percent, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:stop, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp parse_score("viewer"), do: :viewer
  defp parse_score("streamer"), do: :streamer
  defp parse_score("viewer streamer"), do: :both
  defp parse_score("large"), do: :large
  defp parse_score(_), do: :player

  defp overlay_width(:large), do: 1300
  defp overlay_width(:player), do: 480 * 2.5
  defp overlay_width(:both), do: 480
  defp overlay_width(_), do: 240

  defp overlay_height(:large), do: 1000
  defp overlay_height(_), do: 240
end
