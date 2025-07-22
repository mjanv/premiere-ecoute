defmodule PremiereEcouteWeb.Sessions.Components.SpotifyPlayer do
  @moduledoc false

  use PremiereEcouteWeb, :live_component

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :player_state, SpotifyApi.Player.default())}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, :current_user, assigns.current_user)
    socket = assign(socket, :current_scope, assigns.current_scope)
    socket = assign(socket, :listening_session, assigns.listening_session)
    socket = assign(socket, :player_state, assigns.player_state)

    {:ok, socket}
  end

  def refresh_state(socket) do
    case SpotifyApi.get_playback_state(socket.assigns.current_scope) do
      {:ok, state} ->
        assign(socket, :player_state, state)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Cannot read playback state"))
        |> assign(:player_state, SpotifyApi.Player.default())
    end
  end

  @impl true
  def handle_event("toggle_playback", _params, socket) do
    case socket.assigns.player_state do
      %{"is_playing" => true} = state ->
        case SpotifyApi.pause_playback(socket.assigns.current_scope) do
          {:ok, _} ->
            socket = assign(socket, :player_state, %{state | "is_playing" => false})
            {:noreply, put_flash(socket, :info, gettext("Spotify playback paused"))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to pause: %{reason}", reason: reason))}
        end

      %{"is_playing" => false} = state ->
        case SpotifyApi.start_playback(socket.assigns.current_scope) do
          {:ok, _} ->
            socket = assign(socket, :player_state, %{state | "is_playing" => true})
            {:noreply, put_flash(socket, :info, gettext("Spotify playback resumed"))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to play: %{reason}", reason: reason))}
        end
    end
  end

  @impl true
  def handle_event("next_track", _params, socket) do
    %{listening_session: session} = socket.assigns

    case ListeningSession.next_track(session) do
      {:ok, session} ->
        SpotifyApi.start_resume_playback(socket.assigns.current_scope, session.current_track)
        send(self(), {:session_updated, session})
        {:noreply, put_flash(socket, :info, gettext("Next track"))}

      {:error, :no_tracks_left} ->
        {:noreply, put_flash(socket, :info, gettext("Already at the last track"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to go to next track"))}
    end
  end

  @impl true
  def handle_event("previous_track", _params, socket) do
    %{listening_session: session} = socket.assigns

    case ListeningSession.previous_track(session) do
      {:ok, session} ->
        SpotifyApi.start_resume_playback(socket.assigns.current_scope, session.current_track)
        send(self(), {:session_updated, session})
        {:noreply, put_flash(socket, :info, gettext("Previous track"))}

      {:error, :no_tracks_left} ->
        {:noreply, put_flash(socket, :info, gettext("Already at the first track"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to go to previous track"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <h4 class="text-sm font-medium text-gray-300 uppercase tracking-wide">
          Spotify
        </h4>
        <div class="flex items-center space-x-2">
          <%= if @player_state["is_playing"] do %>
            <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
            <span class="text-xs text-green-400">{@player_state["device"]["name"]}</span>
          <% else %>
            <div class="w-2 h-2 bg-red-500 rounded-full"></div>
            <span class="text-xs text-red-500">{gettext("Not playing")}</span>
          <% end %>
        </div>
      </div>
      
    <!-- Current Track Status -->
      <%= if @player_state["item"] do %>
        <div class="bg-white/5 rounded-lg p-3 space-y-3">
          <p class="text-sm font-medium text-white truncate">
            {@player_state["item"]["name"]}
          </p>
          <div class="flex items-center justify-between text-xs text-gray-400">
            <span>{gettext("Progress:")}</span>
            <span>
              {format_duration(@player_state["item"]["progress_ms"])} / {format_duration(@player_state["item"]["duration_ms"])}
            </span>
          </div>
        </div>
      <% else %>
        <div class="bg-white/5 rounded-lg p-3">
          <p class="text-xs text-gray-400 text-center">{gettext("No track selected")}</p>
        </div>
      <% end %>

      <div class="flex space-x-2">
        <button
          phx-click="previous_track"
          phx-target={@myself}
          class="flex-1 bg-white/10 hover:bg-white/20 text-white py-2 px-3 rounded-lg font-medium transition-colors text-sm flex items-center justify-center space-x-2"
        >
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path d="M8.445 14.832A1 1 0 0010 14v-2.798l5.445 3.63A1 1 0 0017 14V6a1 1 0 00-1.555-.832L10 8.798V6a1 1 0 00-1.555-.832l-6 4a1 1 0 000 1.664l6 4z" />
          </svg>
          <span>{gettext("Previous")}</span>
        </button>
        <button
          phx-click="toggle_playback"
          phx-target={@myself}
          class="flex-1 bg-green-600 hover:bg-green-700 text-white py-2 px-3 rounded-lg font-medium transition-colors text-sm flex items-center justify-center space-x-2"
        >
          <%= if @player_state["is_playing"] do %>
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z"
                clip-rule="evenodd"
              />
            </svg>
            <span>{gettext("Pause")}</span>
          <% else %>
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z"
                clip-rule="evenodd"
              />
            </svg>
            <span>{gettext("Play")}</span>
          <% end %>
        </button>
        <button
          phx-click="next_track"
          phx-target={@myself}
          class="flex-1 bg-white/10 hover:bg-white/20 text-white py-2 px-3 rounded-lg font-medium transition-colors text-sm flex items-center justify-center space-x-2"
        >
          <span>{gettext("Next")}</span>
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path d="M4.555 5.168A1 1 0 003 6v8a1 1 0 001.555.832L10 11.202V14a1 1 0 001.555.832l6-4a1 1 0 000-1.664l-6-4A1 1 0 0010 6v2.798l-5.445-3.63z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  def format_duration(nil), do: "--:--"

  def format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
end
