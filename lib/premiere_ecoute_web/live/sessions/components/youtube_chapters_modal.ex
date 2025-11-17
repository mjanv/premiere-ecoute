defmodule PremiereEcouteWeb.Sessions.Components.YoutubeChaptersModal do
  @moduledoc """
  LiveComponent for exporting track markers as YouTube chapter timestamps.

  AIDEV-NOTE: Modal component that displays track markers in YouTube Studio chapter format
  with an adjustable time bias slider. Time-adjusted markers are computed client-side and
  NOT persisted to database.
  """
  use PremiereEcouteWeb, :live_component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(socket) do
    {:ok, assign(socket, time_bias: 0)}
  end

  @impl true
  def update(assigns, socket) do
    session = assigns.listening_session

    # Preload track markers with session data
    session_with_markers =
      session
      |> Repo.preload([:track_markers, album: :tracks, playlist: :tracks])

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:listening_session, session_with_markers)
     |> assign(:time_bias, 0)
     |> assign(:youtube_chapters, format_youtube_chapters(session_with_markers, 0))}
  end

  @impl true
  def handle_event("update_bias", %{"bias" => bias}, socket) do
    {bias_value, _} = Integer.parse(bias)
    chapters = format_youtube_chapters(socket.assigns.listening_session, bias_value)

    {:noreply,
     socket
     |> assign(:time_bias, bias_value)
     |> assign(:youtube_chapters, chapters)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    send(self(), {:youtube_chapters_modal_closed})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <!-- Background overlay -->
      <div class="fixed inset-0 bg-black/70 transition-opacity" phx-click="close_modal" phx-target={@myself}></div>

      <!-- Modal panel -->
      <div class="flex min-h-screen items-center justify-center p-4">
        <div class="relative w-full max-w-2xl transform overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 to-gray-900 p-8 shadow-2xl transition-all border border-purple-500/30">
          <!-- Header -->
          <div class="flex items-start justify-between mb-6">
            <div>
              <h3 class="text-2xl font-bold text-white mb-2" id="modal-title">
                {gettext("YouTube Chapters Export")}
              </h3>
              <p class="text-sm text-gray-400">
                {gettext("Copy and paste these timestamps into your YouTube video description")}
              </p>
            </div>
            <button
              type="button"
              phx-click="close_modal"
              phx-target={@myself}
              class="rounded-lg p-2 text-gray-400 hover:bg-white/10 hover:text-white transition-colors"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Time Bias Slider -->
          <div class="mb-6">
            <div class="flex items-center justify-between mb-2">
              <label class="text-sm font-medium text-purple-300">
                {gettext("Time Bias")}
              </label>
              <span class="text-sm font-mono text-white bg-purple-600/30 px-3 py-1 rounded-lg">
                {if @time_bias >= 0, do: "+", else: ""}{@time_bias}s
              </span>
            </div>
            <input
              type="range"
              min="-60"
              max="60"
              value={@time_bias}
              phx-change="update_bias"
              phx-target={@myself}
              name="bias"
              class="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-purple-600"
            />
            <div class="flex justify-between text-xs text-gray-400 mt-1">
              <span>-60s</span>
              <span>0s</span>
              <span>+60s</span>
            </div>
            <p class="text-xs text-gray-500 mt-2">
              {gettext("Adjust if your video recording started before/after the session")}
            </p>
          </div>

          <!-- YouTube Chapters Textbox -->
          <div class="mb-6">
            <div class="flex items-center justify-between mb-2">
              <label class="text-sm font-medium text-purple-300">
                {gettext("Chapters")}
              </label>
              <button
                type="button"
                onclick={"navigator.clipboard.writeText(document.getElementById('youtube-chapters-text').value)"}
                class="text-xs bg-purple-600 hover:bg-purple-700 text-white px-3 py-1 rounded-lg transition-colors flex items-center space-x-1"
              >
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
                <span>{gettext("Copy")}</span>
              </button>
            </div>
            <textarea
              id="youtube-chapters-text"
              readonly
              rows="12"
              class="w-full bg-black/50 border border-gray-700 rounded-lg p-4 text-white font-mono text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 resize-none"
            >{@youtube_chapters}</textarea>
            <p class="text-xs text-gray-500 mt-2">
              {gettext("YouTube requires the first chapter to start at 0:00")}
            </p>
          </div>

          <!-- Footer -->
          <div class="flex justify-end space-x-3">
            <button
              type="button"
              phx-click="close_modal"
              phx-target={@myself}
              class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
            >
              {gettext("Close")}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # AIDEV-NOTE: Format track markers as YouTube chapter timestamps with time bias
  defp format_youtube_chapters(%ListeningSession{track_markers: []}, _bias) do
    "# No track markers found\n# Start the session and play tracks to generate markers"
  end

  defp format_youtube_chapters(%ListeningSession{track_markers: markers} = session, bias) do
    markers
    |> Enum.sort_by(& &1.started_at, {:asc, DateTime})
    |> Enum.map(fn marker ->
      # Find the track info based on source
      track_name = get_track_name(session, marker)

      # Calculate time from session start with bias
      time_offset = calculate_time_offset(session, marker, bias)

      # Format as YouTube chapter (M:SS or H:MM:SS)
      timestamp = format_timestamp(time_offset)

      "#{timestamp} #{track_name}"
    end)
    |> Enum.join("\n")
  end

  defp get_track_name(%ListeningSession{source: :album, album: album}, marker) do
    track = Enum.find(album.tracks, &(&1.id == marker.track_id))
    if track, do: track.name, else: "Track #{marker.track_number}"
  end

  defp get_track_name(%ListeningSession{source: :playlist, playlist: playlist}, marker) do
    track = Enum.find(playlist.tracks, &(&1.id == marker.track_id))
    if track, do: track.name, else: "Track #{marker.track_number}"
  end

  defp calculate_time_offset(session, marker, bias) do
    # Calculate seconds from session start
    seconds = DateTime.diff(marker.started_at, session.started_at, :second)

    # Apply bias (can be negative)
    adjusted_seconds = max(0, seconds + bias)

    adjusted_seconds
  end

  defp format_timestamp(total_seconds) do
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    seconds = rem(total_seconds, 60)

    cond do
      hours > 0 ->
        "#{hours}:#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"

      true ->
        "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    end
  end
end
