defmodule PremiereEcouteWeb.SessionLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.Discography.Album

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    listening_session =
      case Integer.parse(session_id) do
        {int_id, ""} -> PremiereEcoute.Sessions.ListeningSession.read(int_id)
        _ -> nil
      end

    case listening_session do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> redirect(to: ~p"/")}

      listening_session ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "session:#{session_id}")
        end

        {:ok,
         socket
         |> assign(:listening_session, listening_session)
         |> assign(:session_id, session_id)
         |> assign_async(:session_data, fn ->
           {:ok, %{session_data: load_session_data(listening_session)}}
         end)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    {:noreply, assign(socket, :listening_session, session)}
  end

  @impl true
  def handle_info({:track_changed, track_info}, socket) do
    {:noreply, assign(socket, :current_track, track_info)}
  end

  @impl true
  def handle_info({:votes_updated, votes}, socket) do
    {:noreply, assign(socket, :votes, votes)}
  end

  @impl true
  def handle_info({:scores_updated, scores}, socket) do
    {:noreply, assign(socket, :scores, scores)}
  end

  defp load_session_data(listening_session) do
    with %Album{} = album <- Album.get(listening_session.album_id),
         {:ok, votes} <- Sessions.get_session_votes(listening_session.id),
         {:ok, scores} <- Sessions.get_session_scores(listening_session.id) do
      %{
        album: album,
        tracks: album.tracks || [],
        votes: votes,
        scores: scores,
        current_track: get_current_track(listening_session)
      }
    else
      error ->
        Logger.error("Failed to load session data: #{inspect(error)}")
        %{error: "Failed to load session data"}
    end
  end

  defp get_current_track(listening_session) do
    case Sessions.get_current_playing_track(listening_session.id) do
      {:ok, track} -> track
    end
  end

  def format_duration(nil), do: "--:--"

  def format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  def session_status_class(:preparing), do: "bg-yellow-900/30 text-yellow-400"
  def session_status_class(:active), do: "bg-green-900/30 text-green-400"
  def session_status_class(:stopped), do: "bg-gray-700 text-gray-300"

  def track_score(track_id, scores) do
    case Enum.find(scores, &(&1.track_id == track_id)) do
      nil -> 0
      score -> score.average_score || 0
    end
  end

  def track_votes_count(track_id, votes) do
    votes
    |> Enum.filter(&(&1.track_id == track_id))
    |> length()
  end
end
