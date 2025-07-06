defmodule PremiereEcouteWeb.Sessions.SessionLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi.Player
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    listening_session =
      case Integer.parse(session_id) do
        {int_id, ""} -> ListeningSession.get(int_id)
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

        # AIDEV-NOTE: Get current user for Spotify integration
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

        {:ok,
         socket
         |> assign(:listening_session, listening_session)
         |> assign(:player_state, nil)
         |> assign(:session_id, session_id)
         |> assign(:current_user, current_user)
         |> assign(:show, %{votes: true, scores: true})
         |> assign(:user_current_rating, nil)
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
  def handle_event(
        "start_session",
        _params,
        %{assigns: %{listening_session: session, current_user: user, current_scope: scope}} =
          socket
      ) do
    %StartListeningSession{session_id: session.id, scope: scope}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, updated_session, _} ->
        socket =
          case start_spotify_playback(user, updated_session) do
            {:ok, _} ->
              socket |> put_flash(:info, "Session started and Spotify playback began!")

            {:error, reason} ->
              socket |> put_flash(:warning, "Session started but Spotify failed: #{reason}")
          end

        {:noreply, assign(socket, :listening_session, updated_session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot start session")}
    end
  end

  def handle_event(
        "stop_session",
        _params,
        %{assigns: %{listening_session: session, current_scope: scope}} = socket
      ) do
    %StopListeningSession{session_id: session.id, scope: scope}
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} ->
        {:noreply, assign(socket, :listening_session, session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot stop session")}
    end
  end

  @impl true
  def handle_event("toggle", %{"flag" => flag}, %{assigns: assigns} = socket) do
    {:noreply,
     assign(socket, :show, Map.update!(assigns.show, String.to_atom(flag), fn v -> !v end))}
  end

  # AIDEV-NOTE: Spotify player events are now handled by the LiveComponent

  @impl true
  def handle_event("vote_track", %{"track_id" => track_id, "rating" => rating}, socket) do
    case Integer.parse(track_id) do
      {_int_track_id, ""} ->
        case Integer.parse(rating) do
          {int_rating, ""} when int_rating >= 1 and int_rating <= 10 ->
            socket = assign(socket, :user_current_rating, int_rating)
            {:noreply, put_flash(socket, :info, "Rated track #{int_rating}/10")}

          _ ->
            {:noreply, put_flash(socket, :error, "Invalid rating")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid track")}
    end
  end

  @impl true
  def handle_event(event, _params, socket) do
    {:noreply, put_flash(socket, :info, "Received event: #{event}")}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    # AIDEV-NOTE: Handle session updates from Spotify player component
    socket = assign(socket, :listening_session, session)
    socket = assign(socket, :user_current_rating, nil)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refreshh, socket) do
    socket = PremiereEcouteWeb.Sessions.Components.SpotifyPlayer.refresh_state(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_info(event, socket) do
    {:noreply, put_flash(socket, :info, "Received #{inspect(event)}")}
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
        current_track: nil
      }
    else
      error ->
        Logger.error("Failed to load session data: #{inspect(error)}")
        %{error: "Failed to load session data"}
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

  defp start_spotify_playback(user, session) do
    case user do
      %{spotify_access_token: access_token} when not is_nil(access_token) ->
        # AIDEV-NOTE: Get the current track from the session
        case get_current_track_uri(session) do
          {:ok, track_uri} ->
            Logger.info("Starting Spotify playback for track: #{track_uri}")
            Player.start_playback(access_token, uris: [track_uri])

          {:error, reason} ->
            Logger.warning("Could not get track URI: #{reason}")
            # Try to start playback without specific track
            Player.start_playback(access_token)
        end

      _ ->
        {:error, "No Spotify connection. Connect Spotify in your account settings."}
    end
  end

  defp get_current_track_uri(session) do
    # AIDEV-NOTE: Get the current track from the session and build Spotify URI
    case session.current_track do
      nil ->
        {:error, "No current track"}

      track when is_map(track) and not is_nil(track.spotify_id) ->
        {:ok, "spotify:track:#{track.spotify_id}"}

      _ ->
        {:error, "Track has no Spotify ID"}
    end
  end
end
