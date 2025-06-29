defmodule PremiereEcouteWeb.DashboardLive do
  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Adapters.TwitchAdapter
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted

  require Logger

  @impl true
  def mount(_params, session, socket) do
    PremiereEcouteWeb.PubSub.subscribe("listening_sessions")

    # Get Spotify token from session
    user_spotify_token = Map.get(session, "spotify_token")

    {:ok,
     socket
     |> assign(:page_title, "Streamer Dashboard")
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> assign(:search_albums, AsyncResult.ok([]))
     |> assign(:selected_album, AsyncResult.ok(nil))
     |> assign(:current_session, nil)
     |> assign(:active_voters, 0)
     |> assign(:current_track, nil)
     |> assign(:track_votes, %{})
     |> assign(:session_stats, %{})
     |> assign(:loading, false)
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})
     |> assign(:twitch_poll_id, nil)
     |> assign(:chat_votes, %{})
     |> assign(:poll_results, %{})
     |> assign(:spotify_playback_state, %{is_playing: false, device: nil})
     |> assign(:spotify_devices, [])
     |> assign(:selected_device_id, nil)
     |> assign(:user_spotify_token, user_spotify_token)
     |> then(fn socket ->
       # Initialize Spotify playback state if token is available
       if user_spotify_token do
         schedule_playback_sync()
         socket
       else
         socket
       end
     end)}
  end

  @impl true
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_albums, AsyncResult.loading())
    |> start_async(:search, fn -> PremiereEcoute.search_albums(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_albums", _params, socket), do: {:noreply, socket}

  def handle_event("select_album", %{"album_id" => album_id}, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.loading())
    |> start_async(:select, fn -> PremiereEcoute.get_album(album_id) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("start_session", _params, %{assigns: %{selected_album: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Please select an album first")}
  end

  def handle_event("start_session", _params, %{assigns: %{selected_album: album}} = socket) do
    album = album.result

    command = %StartListeningSession{
      streamer_id: get_streamer_id(socket),
      album_id: album.spotify_id
    }

    PremiereEcouteWeb.PubSub.broadcast("command_bus", command)

    {:noreply, socket}
  end

  def handle_event("pause_playback", _params, socket) do
    case socket.assigns.user_spotify_token do
      nil ->
        {:noreply, put_flash(socket, :error, "Connect Spotify to control playback")}

      token ->
        case SpotifyApi.pause_playback(token, socket.assigns.selected_device_id) do
          {:ok, :paused} ->
            schedule_playback_sync()
            {:noreply, put_flash(socket, :info, "Playback paused")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to pause: #{reason}")}
        end
    end
  end

  def handle_event("resume_playback", _params, socket) do
    case socket.assigns.user_spotify_token do
      nil ->
        {:noreply, put_flash(socket, :error, "Connect Spotify to control playback")}

      token ->
        case SpotifyApi.resume_playback(token, socket.assigns.selected_device_id) do
          {:ok, :playing} ->
            schedule_playback_sync()
            {:noreply, put_flash(socket, :info, "Playback resumed")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to resume: #{reason}")}
        end
    end
  end

  def handle_event("next_track", _params, socket) do
    case {socket.assigns.current_session, socket.assigns.selected_album} do
      {%{id: _session_id}, %{tracks: tracks}} ->
        current_track = socket.assigns.current_track
        current_index = Enum.find_index(tracks, &(&1.spotify_id == current_track.spotify_id))
        next_track = Enum.at(tracks, current_index + 1)

        if next_track do
          # Skip on Spotify if connected
          spotify_result =
            case socket.assigns.user_spotify_token do
              nil ->
                {:ok, :skipped}

              token ->
                SpotifyApi.skip_to_next(token, socket.assigns.selected_device_id)
            end

          # Create new Twitch poll for next track
          streamer_id = get_streamer_id(socket)

          case create_track_poll(next_track, streamer_id) do
            {:ok, poll_id} ->
              schedule_playback_sync()

              flash_message =
                case spotify_result do
                  {:ok, :skipped} -> "Moved to track: #{next_track.name}. New poll created!"
                  {:error, _} -> "Track changed (Spotify skip failed). New poll created!"
                end

              {:noreply,
               socket
               |> assign(:current_track, next_track)
               |> assign(:twitch_poll_id, poll_id)
               |> assign(:chat_votes, %{})
               |> assign(:poll_results, %{})
               |> put_flash(:info, flash_message)}

            {:error, reason} ->
              Logger.error("Failed to create poll for next track: #{inspect(reason)}")

              {:noreply,
               socket
               |> assign(:current_track, next_track)
               |> put_flash(:warning, "Moved to track: #{next_track.name}. Poll creation failed.")}
          end
        else
          {:noreply, put_flash(socket, :info, "This is the last track")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No active session")}
    end
  end

  def handle_event("previous_track", _params, socket) do
    case {socket.assigns.current_session, socket.assigns.selected_album} do
      {%{id: _session_id}, %{tracks: tracks}} ->
        current_track = socket.assigns.current_track
        current_index = Enum.find_index(tracks, &(&1.spotify_id == current_track.spotify_id))

        if current_index > 0 do
          previous_track = Enum.at(tracks, current_index - 1)

          # Skip on Spotify if connected
          spotify_result =
            case socket.assigns.user_spotify_token do
              nil ->
                {:ok, :skipped}

              token ->
                SpotifyApi.skip_to_previous(token, socket.assigns.selected_device_id)
            end

          # Create new Twitch poll for previous track
          streamer_id = get_streamer_id(socket)

          case create_track_poll(previous_track, streamer_id) do
            {:ok, poll_id} ->
              schedule_playback_sync()

              flash_message =
                case spotify_result do
                  {:ok, :skipped} -> "Moved to track: #{previous_track.name}. New poll created!"
                  {:error, _} -> "Track changed (Spotify skip failed). New poll created!"
                end

              {:noreply,
               socket
               |> assign(:current_track, previous_track)
               |> assign(:twitch_poll_id, poll_id)
               |> assign(:chat_votes, %{})
               |> assign(:poll_results, %{})
               |> put_flash(:info, flash_message)}

            {:error, reason} ->
              Logger.error("Failed to create poll for previous track: #{inspect(reason)}")

              {:noreply,
               socket
               |> assign(:current_track, previous_track)
               |> put_flash(
                 :warning,
                 "Moved to track: #{previous_track.name}. Poll creation failed."
               )}
          end
        else
          {:noreply, put_flash(socket, :info, "This is the first track")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No active session")}
    end
  end

  def handle_event("end_session", _params, socket) do
    case socket.assigns.current_session do
      nil ->
        {:noreply, put_flash(socket, :error, "No active session")}

      _session ->
        # Pause Spotify playback when ending session
        if socket.assigns.user_spotify_token do
          SpotifyApi.pause_playback(
            socket.assigns.user_spotify_token,
            socket.assigns.selected_device_id
          )
        end

        {:noreply,
         socket
         |> assign(:current_session, nil)
         |> assign(:current_track, nil)
         |> assign(:track_votes, %{})
         |> assign(:twitch_poll_id, nil)
         |> assign(:chat_votes, %{})
         |> assign(:poll_results, %{})
         |> assign(:spotify_playback_state, %{is_playing: false, device: nil})
         |> put_flash(:info, "Session ended and Spotify playback stopped")}
    end
  end

  @impl true
  def handle_async(:search, {:ok, result}, %{assigns: assigns} = socket) do
    case result do
      {:ok, albums} ->
        socket
        |> assign(:search_albums, AsyncResult.ok(albums))

      {:error, reason} ->
        socket
        |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
        |> put_flash(:error, "Search failed. Please try again.")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
    |> put_flash(:error, "Search failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, result}, %{assigns: assigns} = socket) do
    case result do
      {:ok, album} ->
        socket
        |> assign(:selected_album, AsyncResult.ok(album))

      {:error, reason} ->
        socket
        |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
        |> put_flash(:error, "Selection failed. Please try again.")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info(%SessionStarted{session_id: id}, socket) do
    socket
    |> put_flash(:info, "Listening session started !")
    |> push_patch(to: ~p"/session/#{id}")
    |> then(fn socket -> {:noreply, socket} end)
  end

  # Private helper functions

  defp create_track_poll(track, streamer_id) do
    poll_question = "Rate \"#{track.name}\" (1-10)"
    poll_options = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    case TwitchAdapter.create_poll(streamer_id, poll_question, poll_options) do
      {:ok, poll_id} ->
        # Start monitoring poll results
        spawn(fn -> monitor_poll_results(poll_id) end)
        {:ok, poll_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp monitor_poll_results(poll_id) do
    # Poll for results every 5 seconds
    :timer.sleep(5000)

    case TwitchAdapter.get_poll_results(poll_id) do
      {:ok, results} ->
        Phoenix.PubSub.broadcast(
          PremiereEcoute.PubSub,
          "twitch_chat",
          {:twitch_poll_update, results}
        )

        if results.status == :active do
          monitor_poll_results(poll_id)
        end

      {:error, _reason} ->
        :ok
    end
  end

  defp schedule_playback_sync do
    # Sync playback state in 2 seconds
    Process.send_after(self(), :sync_playback_state, 2000)
  end

  # Template helper functions
  defp format_duration(duration_ms) when is_integer(duration_ms) do
    minutes = div(duration_ms, 60_000)
    seconds = div(rem(duration_ms, 60_000), 1000)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp format_duration(_), do: "0:00"

  defp get_vote_height(vote_value, poll_results) do
    # Calculate height based on actual poll/chat data
    vote_count = get_vote_count(vote_value, poll_results)
    max_votes = get_max_vote_count(poll_results)

    if max_votes > 0 do
      percentage = vote_count / max_votes
      height_class = round(percentage * 16)
      "h-#{min(height_class, 16)}"
    else
      "h-1"
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

  defp get_vote_count(vote_value, poll_results) do
    # Get vote count from Twitch poll results
    case poll_results do
      %{options: options} ->
        option = Enum.find(options, &(&1.text == to_string(vote_value)))
        if option, do: option.votes, else: 0

      _ ->
        0
    end
  end

  defp get_max_vote_count(poll_results) do
    case poll_results do
      %{options: options} ->
        options
        |> Enum.map(& &1.votes)
        |> Enum.max(fn -> 0 end)

      _ ->
        0
    end
  end

  defp calculate_average_score(poll_results, chat_votes) do
    # Calculate average from both poll and chat votes
    poll_total = calculate_poll_average(poll_results)
    chat_total = calculate_chat_average(chat_votes)

    total_votes = map_size(chat_votes) + (poll_results[:total_votes] || 0)

    if total_votes > 0 do
      Float.round((poll_total + chat_total) / total_votes, 1)
    else
      0.0
    end
  end

  defp calculate_poll_average(poll_results) do
    case poll_results do
      %{options: options} ->
        options
        |> Enum.reduce(0, fn option, acc ->
          vote_value = String.to_integer(option.text)
          acc + vote_value * option.votes
        end)

      _ ->
        0
    end
  end

  defp calculate_chat_average(chat_votes) do
    chat_votes
    |> Map.values()
    |> Enum.sum()
  end

  defp get_streamer_id(socket) do
    case socket.assigns.current_scope do
      %{user: %{id: user_id}} -> to_string(user_id)
      _ -> "anonymous_streamer"
    end
  end
end
