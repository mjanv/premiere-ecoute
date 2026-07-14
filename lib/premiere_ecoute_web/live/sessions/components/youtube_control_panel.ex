defmodule PremiereEcouteWeb.Sessions.Components.YoutubeControlPanel do
  @moduledoc """
  YouTube clip remote control LiveView component.

  Sends play/pause/volume commands to the session's OBS overlay page
  (ClipOverlayLive) via PubSub — this dashboard has no local player of its own,
  it only remote-controls the one embedded in the overlay.
  """

  use PremiereEcouteWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(:listening_session, assigns.listening_session)
    |> assign(:clip_progress, assigns.clip_progress)
    |> assign_new(:volume, fn -> 100 end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("clip_play", _params, socket) do
    broadcast_command(socket, %{command: "play"})
    {:noreply, socket}
  end

  @impl true
  def handle_event("clip_pause", _params, socket) do
    broadcast_command(socket, %{command: "pause"})
    {:noreply, socket}
  end

  @impl true
  def handle_event("clip_volume", %{"volume" => volume}, socket) do
    volume = to_integer(volume)
    broadcast_command(socket, %{command: "volume", value: volume})
    {:noreply, assign(socket, :volume, volume)}
  end

  @impl true
  def handle_event("clip_seek", %{"position" => position}, socket) do
    broadcast_command(socket, %{command: "seek", value: to_integer(position)})
    {:noreply, socket}
  end

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)

  defp broadcast_command(socket, command) do
    PremiereEcoute.PubSub.broadcast("session:#{socket.assigns.listening_session.id}", {:clip_command, command})
  end

  defp seconds_timer(nil), do: "--:--"
  defp seconds_timer(seconds), do: PremiereEcouteCore.Duration.timer(round(seconds * 1000))

  defp whole_seconds(nil), do: 0
  defp whole_seconds(seconds), do: round(seconds)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <h4 class="text-sm font-medium text-gray-300 uppercase tracking-wide">
          YouTube
        </h4>
        <span class="text-xs text-gray-400">{gettext("Controls the OBS overlay player")}</span>
      </div>

      <div class="flex space-x-2">
        <button
          phx-click="clip_play"
          phx-target={@myself}
          class={[
            "flex-1 py-2 px-2 rounded-lg font-medium transition-colors text-xs flex items-center justify-center space-x-1",
            if(playing?(@clip_progress) == false,
              do: "bg-red-600 hover:bg-red-700 text-white clip-button-active",
              else: "bg-white/10 hover:bg-white/20 text-gray-300"
            )
          ]}
        >
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z"
              clip-rule="evenodd"
            />
          </svg>
          <span>{gettext("Play")}</span>
        </button>
        <button
          phx-click="clip_pause"
          phx-target={@myself}
          class={[
            "flex-1 py-2 px-2 rounded-lg font-medium transition-colors text-xs flex items-center justify-center space-x-1",
            if(playing?(@clip_progress) == true,
              do: "bg-red-600 hover:bg-red-700 text-white clip-button-active",
              else: "bg-white/10 hover:bg-white/20 text-gray-300"
            )
          ]}
        >
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z"
              clip-rule="evenodd"
            />
          </svg>
          <span>{gettext("Pause")}</span>
        </button>
      </div>

      <div class="space-y-1">
        <div class="flex items-center justify-between text-xs text-gray-400">
          <span>{seconds_timer(@clip_progress && @clip_progress.current_time)}</span>
          <span>{seconds_timer(@clip_progress && @clip_progress.duration)}</span>
        </div>
        <div
          id="clip-progress-bar"
          phx-hook="ClipProgressBar"
          phx-target={@myself}
          data-current={whole_seconds(@clip_progress && @clip_progress.current_time)}
          data-duration={whole_seconds(@clip_progress && @clip_progress.duration)}
          class="relative w-full h-2 bg-white/10 rounded-full cursor-pointer"
        >
          <div data-role="fill" class="absolute inset-y-0 left-0 bg-red-600 rounded-full" style="width: 0%"></div>
        </div>
      </div>

      <div class="space-y-1">
        <div class="flex items-center space-x-1.5 text-xs text-gray-400">
          <svg class="w-3.5 h-3.5 shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.707.707L4.586 13H2a1 1 0 01-1-1V8a1 1 0 011-1h2.586l3.707-3.707a1 1 0 011.09-.217z" />
          </svg>
          <span>{gettext("Volume")}</span>
        </div>
        <div
          id="clip-volume-bar"
          phx-hook="ClipVolumeBar"
          phx-target={@myself}
          data-volume={@volume}
          class="relative w-full h-2 bg-white/10 rounded-full cursor-pointer"
        >
          <div data-role="fill" class="absolute inset-y-0 left-0 bg-blue-600 rounded-full" style="width: 0%"></div>
        </div>
      </div>
    </div>
    """
  end

  defp playing?(nil), do: nil
  defp playing?(progress), do: Map.get(progress, :playing)
end
