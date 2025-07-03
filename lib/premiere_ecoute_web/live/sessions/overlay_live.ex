defmodule PremiereEcouteWeb.Sessions.OverlayLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession

  # AIDEV-NOTE: OBS overlay LiveView for displaying real-time session statistics during livestreams

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    listening_session =
      case Integer.parse(id) do
        {int_id, ""} -> ListeningSession.get(int_id)
        _ -> nil
      end

    case listening_session do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> assign(:session_id, id)
         |> assign(:listening_session, nil)
         |> assign(:current_average_score, 0.0)
         |> assign(:total_votes, 0)
         |> assign(:tracks_rated, 0)}

      listening_session ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{id}")
        end

        {:ok,
         socket
         |> assign(:session_id, id)
         |> assign(:listening_session, listening_session)
         |> assign(:current_average_score, 0.0)
         |> assign(:total_votes, 0)
         |> assign(:tracks_rated, 0)
         |> assign_async(:stats, fn ->
           {:ok, %{stats: load_session_stats(id)}}
         end)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:track_changed, _track}, socket) do
    # Reload stats when track changes
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:stats, fn ->
       {:ok, %{stats: load_session_stats(session_id)}}
     end)}
  end

  @impl true
  def handle_info({:vote_cast, _vote_data}, socket) do
    # Reload stats when new vote is cast
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:stats, fn ->
       {:ok, %{stats: load_session_stats(session_id)}}
     end)}
  end

  @impl true
  def handle_info({:score_updated, _score_data}, socket) do
    # Reload stats when scores are updated
    session_id = socket.assigns.session_id

    {:noreply,
     socket
     |> assign_async(:stats, fn ->
       {:ok, %{stats: load_session_stats(session_id)}}
     end)}
  end

  @impl true
  def handle_info(_event, socket) do
    # Ignore other events
    {:noreply, socket}
  end

  @impl true
  def handle_async(:stats, {:ok, %{stats: stats}}, socket) do
    {:noreply,
     socket
     |> assign(:current_average_score, stats.average_score)
     |> assign(:total_votes, stats.total_votes)
     |> assign(:tracks_rated, stats.tracks_rated)}
  end

  @impl true
  def handle_async(:stats, {:exit, reason}, socket) do
    Logger.error("Failed to load session stats: #{inspect(reason)}")
    {:noreply, socket}
  end

  defp load_session_stats(session_id) do
    session_id_int =
      case Integer.parse(session_id) do
        {int_id, ""} -> int_id
        _ -> nil
      end

    case session_id_int do
      nil ->
        %{average_score: 0.0, total_votes: 0, tracks_rated: 0}

      int_id ->
        case Sessions.get_session_scores(int_id) do
          {:ok, scores} ->
            calculate_session_stats(scores)
        end
    end
  end

  defp calculate_session_stats(scores) do
    if Enum.empty?(scores) do
      %{average_score: 0.0, total_votes: 0, tracks_rated: 0}
    else
      total_votes = Enum.sum(Enum.map(scores, & &1.vote_count))

      # Calculate weighted average across all tracks
      weighted_sum =
        scores
        |> Enum.map(fn score ->
          Decimal.to_float(score.average_score) * score.vote_count
        end)
        |> Enum.sum()

      average_score =
        if total_votes > 0 do
          weighted_sum / total_votes
        else
          0.0
        end

      %{
        average_score: Float.round(average_score, 2),
        total_votes: total_votes,
        tracks_rated: length(scores)
      }
    end
  end
end
