defmodule PremiereEcouteWeb.DashboardLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Adapters.SpotifyAdapter
  alias PremiereEcoute.Core.Commands
  alias PremiereEcoute.Core.Events
  alias PremiereEcoute.Core.Entities

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to session events for real-time updates
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "listening_sessions")
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "voting_updates")

    {:ok,
     socket
     |> assign(:page_title, "Streamer Dashboard")
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> assign(:search_results, [])
     |> assign(:selected_album, nil)
     |> assign(:current_session, nil)
     |> assign(:active_voters, 0)
     |> assign(:current_track, nil)
     |> assign(:track_votes, %{})
     |> assign(:session_stats, %{})
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    send(self(), {:search_spotify, query})

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:search_results, [])}
  end

  def handle_event("search_albums", _params, socket) do
    {:noreply, assign(socket, :search_results, [])}
  end

  def handle_event("select_album", %{"album_id" => album_id}, socket) do
    case SpotifyAdapter.get_album_with_tracks(album_id) do
      {:ok, album} ->
        {:noreply,
         socket
         |> assign(:selected_album, album)
         |> put_flash(:info, "Album selected: #{album.name}")}

      {:error, reason} ->
        Logger.error("Failed to fetch album: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to load album details")}
    end
  end

  def handle_event("start_session", _params, socket) do
    case socket.assigns.selected_album do
      nil ->
        {:noreply, put_flash(socket, :error, "Please select an album first")}

      album ->
        # Create start listening command
        command = %Commands.StartListening{
          command_id: generate_id(),
          streamer_id: get_streamer_id(socket),
          album_id: album.spotify_id,
          timestamp: DateTime.utc_now()
        }

        # Process command (would normally go through command handler)
        session = create_listening_session(command, album)

        # Broadcast session started event
        event = %Events.SessionStarted{
          event_id: generate_id(),
          session_id: session.id,
          streamer_id: command.streamer_id,
          album_id: command.album_id,
          timestamp: DateTime.utc_now()
        }

        Phoenix.PubSub.broadcast(
          PremiereEcoute.PubSub,
          "listening_sessions",
          {:session_started, event}
        )

        {:noreply,
         socket
         |> assign(:current_session, session)
         |> assign(:current_track, List.first(album.tracks))
         |> put_flash(:info, "Listening session started!")}
    end
  end

  def handle_event("cast_vote", %{"value" => value}, socket)
      when value in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] do
    vote_value = String.to_integer(value)

    case {socket.assigns.current_session, socket.assigns.current_track} do
      {%{id: session_id}, %{spotify_id: track_id}} ->
        command = %Commands.CastVote{
          command_id: generate_id(),
          session_id: session_id,
          track_id: track_id,
          voter_id: get_streamer_id(socket),
          vote_value: vote_value,
          voter_type: :streamer,
          timestamp: DateTime.utc_now()
        }

        # Process vote (would normally go through command handler)
        event = %Events.VoteCast{
          event_id: generate_id(),
          session_id: command.session_id,
          track_id: command.track_id,
          voter_id: command.voter_id,
          vote_value: command.vote_value,
          voter_type: command.voter_type,
          timestamp: DateTime.utc_now()
        }

        Phoenix.PubSub.broadcast(
          PremiereEcoute.PubSub,
          "voting_updates",
          {:vote_cast, event}
        )

        track_votes = Map.put(socket.assigns.track_votes, track_id, vote_value)

        {:noreply,
         socket
         |> assign(:track_votes, track_votes)
         |> put_flash(:info, "Vote cast: #{vote_value}/10")}

      _ ->
        {:noreply, put_flash(socket, :error, "No active session or track")}
    end
  end

  def handle_event("next_track", _params, socket) do
    case {socket.assigns.current_session, socket.assigns.selected_album} do
      {%{id: session_id}, %{tracks: tracks}} ->
        current_track = socket.assigns.current_track
        current_index = Enum.find_index(tracks, &(&1.spotify_id == current_track.spotify_id))
        next_track = Enum.at(tracks, current_index + 1)

        if next_track do
          {:noreply,
           socket
           |> assign(:current_track, next_track)
           |> put_flash(:info, "Moved to track: #{next_track.name}")}
        else
          {:noreply, put_flash(socket, :info, "This is the last track")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No active session")}
    end
  end

  def handle_event("end_session", _params, socket) do
    case socket.assigns.current_session do
      nil ->
        {:noreply, put_flash(socket, :error, "No active session")}

      session ->
        {:noreply,
         socket
         |> assign(:current_session, nil)
         |> assign(:current_track, nil)
         |> assign(:track_votes, %{})
         |> put_flash(:info, "Session ended")}
    end
  end

  @impl true
  def handle_info({:search_spotify, query}, socket) do
    case SpotifyAdapter.search_albums(query) do
      {:ok, results} ->
        {:noreply,
         socket
         |> assign(:search_results, results)
         |> assign(:loading, false)}

      {:error, reason} ->
        Logger.error("Spotify search failed: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:search_results, [])
         |> assign(:loading, false)
         |> put_flash(:error, "Search failed. Please try again.")}
    end
  end

  def handle_info({:session_started, _event}, socket) do
    {:noreply, assign(socket, :active_voters, socket.assigns.active_voters + 1)}
  end

  def handle_info({:vote_cast, event}, socket) do
    # Update real-time vote display
    {:noreply, assign(socket, :active_voters, socket.assigns.active_voters + 1)}
  end

  # Private helper functions

  # Template helper functions
  defp format_duration(duration_ms) when is_integer(duration_ms) do
    minutes = div(duration_ms, 60000)
    seconds = div(rem(duration_ms, 60000), 1000)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp format_duration(_), do: "0:00"

  defp get_vote_height(vote_value) do
    case vote_value do
      1 -> "h-2"
      2 -> "h-4"
      3 -> "h-8"
      4 -> "h-12"
      5 -> "h-10"
      6 -> "h-14"
      7 -> "h-16"
      8 -> "h-12"
      9 -> "h-8"
      10 -> "h-6"
    end
  end

  defp get_vote_color(vote_value) do
    case vote_value do
      1 -> "bg-red-500"
      2 -> "bg-orange-500"
      3 -> "bg-yellow-500"
      4 -> "bg-lime-500"
      5 -> "bg-green-500"
      6 -> "bg-teal-500"
      7 -> "bg-blue-500"
      8 -> "bg-indigo-500"
      9 -> "bg-purple-500"
      10 -> "bg-pink-500"
    end
  end

  defp generate_id, do: Ecto.UUID.generate()

  defp get_streamer_id(socket) do
    case socket.assigns.current_scope do
      %{user: %{id: user_id}} -> to_string(user_id)
      _ -> "anonymous_streamer"
    end
  end

  defp create_listening_session(command, album) do
    %Entities.ListeningSession{
      id: generate_id(),
      streamer_id: command.streamer_id,
      album_id: command.album_id,
      current_track_id: List.first(album.tracks).spotify_id,
      status: :active,
      started_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end
