defmodule PremiereEcouteWeb.DashboardLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Adapters.{SpotifyAdapter, TwitchAdapter}
  alias PremiereEcoute.Core.Commands
  alias PremiereEcoute.Core.Events
  alias PremiereEcoute.Core.Entities

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to session events for real-time updates
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "listening_sessions")
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "voting_updates")
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "twitch_chat")

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
     |> assign(:loading, false)
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})
     |> assign(:twitch_poll_id, nil)
     |> assign(:chat_votes, %{})
     |> assign(:poll_results, %{})
     |> assign(:spotify_playback_state, %{is_playing: false, device: nil})
     |> assign(:spotify_devices, [])
     |> assign(:selected_device_id, nil)
     |> assign(:user_spotify_token, nil)}
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
         |> assign(:search_results, [])
         |> assign(:loading, false)
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
        first_track = List.first(album.tracks)

        # Start chat listener for vote commands
        streamer_id = get_streamer_id(socket)
        start_chat_listener(streamer_id)

        # Get user's Spotify token for playback control
        user_token = get_user_spotify_token(socket)

        # Start album playback on Spotify if token available
        playback_result =
          if user_token do
            SpotifyAdapter.start_album_playback(user_token, album.spotify_id)
          else
            {:error, "No Spotify authentication"}
          end

        # Create Twitch poll for the first track
        case create_track_poll(first_track, streamer_id) do
          {:ok, poll_id} ->
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

            # Update playback state
            schedule_playback_sync()

            flash_message =
              case playback_result do
                {:ok, :playing} ->
                  "Session started! Playing on Spotify and Twitch poll created."

                {:error, _} ->
                  "Session started with Twitch poll. Connect Spotify for playback control."
              end

            {:noreply,
             socket
             |> assign(:current_session, session)
             |> assign(:current_track, first_track)
             |> assign(:twitch_poll_id, poll_id)
             |> assign(:user_spotify_token, user_token)
             |> put_flash(:info, flash_message)}

          {:error, reason} ->
            Logger.error("Failed to create Twitch poll: #{inspect(reason)}")

            {:noreply,
             socket
             |> assign(:current_session, session)
             |> assign(:current_track, first_track)
             |> assign(:user_spotify_token, user_token)
             |> put_flash(:warning, "Session started, but Twitch poll failed to create")}
        end
    end
  end

  def handle_event("pause_playback", _params, socket) do
    case socket.assigns.user_spotify_token do
      nil ->
        {:noreply, put_flash(socket, :error, "Connect Spotify to control playback")}

      token ->
        case SpotifyAdapter.pause_playback(token, socket.assigns.selected_device_id) do
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
        case SpotifyAdapter.resume_playback(token, socket.assigns.selected_device_id) do
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
                SpotifyAdapter.skip_to_next(token, socket.assigns.selected_device_id)
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
                SpotifyAdapter.skip_to_previous(token, socket.assigns.selected_device_id)
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
          SpotifyAdapter.pause_playback(
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

  def handle_event("select_device", %{"device_id" => device_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_device_id, device_id)
     |> put_flash(:info, "Spotify device selected")}
  end

  def handle_event("refresh_devices", _params, socket) do
    case socket.assigns.user_spotify_token do
      nil ->
        {:noreply, put_flash(socket, :error, "Connect Spotify to see devices")}

      token ->
        case SpotifyAdapter.get_available_devices(token) do
          {:ok, devices} ->
            {:noreply,
             socket
             |> assign(:spotify_devices, devices)
             |> put_flash(:info, "Devices refreshed")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to get devices: #{reason}")}
        end
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

  def handle_info(:sync_playback_state, socket) do
    case socket.assigns.user_spotify_token do
      nil ->
        {:noreply, socket}

      token ->
        case SpotifyAdapter.get_playback_state(token) do
          {:ok, playback_state} ->
            {:noreply, assign(socket, :spotify_playback_state, playback_state)}

          {:error, _reason} ->
            {:noreply, socket}
        end
    end
  end

  def handle_info({:session_started, _event}, socket) do
    {:noreply, assign(socket, :active_voters, socket.assigns.active_voters + 1)}
  end

  def handle_info({:vote_cast, _event}, socket) do
    # Update real-time vote display from Twitch
    {:noreply, assign(socket, :active_voters, socket.assigns.active_voters + 1)}
  end

  def handle_info({:twitch_chat_vote, %{user: user, vote: vote}}, socket) do
    # Handle chat vote commands like "!vote 8"
    if socket.assigns.current_track do
      chat_votes = Map.put(socket.assigns.chat_votes, user, vote)

      {:noreply,
       socket
       |> assign(:chat_votes, chat_votes)
       |> assign(:active_voters, map_size(chat_votes))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:twitch_poll_update, poll_results}, socket) do
    # Handle Twitch poll result updates
    {:noreply, assign(socket, :poll_results, poll_results)}
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

  defp start_chat_listener(streamer_id) do
    chat_callback = fn message ->
      # Parse chat for vote commands like "!vote 8"
      case parse_vote_command(message) do
        {:ok, vote} ->
          Phoenix.PubSub.broadcast(
            PremiereEcoute.PubSub,
            "twitch_chat",
            {:twitch_chat_vote, %{user: message.user, vote: vote}}
          )

        :error ->
          :ok
      end
    end

    case TwitchAdapter.listen_to_chat(streamer_id, chat_callback) do
      {:ok, _pid} -> :ok
      {:ok, _pid} -> :ok
    end
  end

  defp parse_vote_command(%{message: message}) do
    case Regex.run(~r/^!vote\s+(\d+)$/i, String.trim(message)) do
      [_, vote_str] ->
        case Integer.parse(vote_str) do
          {vote, ""} when vote >= 1 and vote <= 10 ->
            {:ok, vote}

          _ ->
            :error
        end

      _ ->
        :error
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

  defp get_user_spotify_token(socket) do
    # In a real implementation, this would get the user's Spotify token from the session/database
    # For now, we'll use nil (playback control will be disabled)
    # This would be set after Spotify OAuth authentication
    case socket.assigns.current_scope do
      %{user: %{spotify_token: token}} when is_binary(token) -> token
      _ -> nil
    end
  end

  # Template helper functions
  defp format_duration(duration_ms) when is_integer(duration_ms) do
    minutes = div(duration_ms, 60000)
    seconds = div(rem(duration_ms, 60000), 1000)
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
