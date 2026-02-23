defmodule PremiereEcouteWeb.Sessions.Components.YoutubeChaptersModal do
  @moduledoc """
  LiveComponent for exporting track markers as YouTube chapter timestamps.
  """

  use PremiereEcouteWeb, :live_component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker

  @impl true
  def mount(socket) do
    {:ok, assign(socket, time_bias: 0, include_chat_note: false, include_streamer_note: false)}
  end

  @impl true
  def update(assigns, socket) do
    session = assigns.listening_session
    time_bias = socket.assigns[:time_bias] || 0
    include_chat_note = socket.assigns[:include_chat_note] || false
    include_streamer_note = socket.assigns[:include_streamer_note] || false

    # AIDEV-NOTE: report may be nil (no votes cast) or an unexpected type during async loading; extract_score handles all cases
    report = assigns[:report]
    chat_note_value = extract_score(report, "viewer_score")
    streamer_note_value = extract_score(report, "streamer_score")
    chapters = TrackMarker.format_youtube_chapters(session, time_bias)

    socket
    |> assign(assigns)
    |> assign(:listening_session, session)
    |> assign(:time_bias, time_bias)
    |> assign(:include_chat_note, include_chat_note)
    |> assign(:include_streamer_note, include_streamer_note)
    |> assign(:chat_note_value, chat_note_value)
    |> assign(:streamer_note_value, streamer_note_value)
    |> assign(:youtube_chapters, chapters)
    |> assign(:export_text, build_export_text(chapters, chat_note_value, streamer_note_value, include_chat_note, include_streamer_note))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("update_bias", %{"bias" => bias}, socket) do
    bias_value = String.to_integer(bias)
    chapters = TrackMarker.format_youtube_chapters(socket.assigns.listening_session, bias_value)

    socket
    |> assign(:time_bias, bias_value)
    |> assign(:youtube_chapters, chapters)
    |> assign(:export_text, build_export_text(chapters, socket.assigns.chat_note_value, socket.assigns.streamer_note_value, socket.assigns.include_chat_note, socket.assigns.include_streamer_note))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("toggle_chat_note", _params, socket) do
    include = !socket.assigns.include_chat_note

    socket
    |> assign(:include_chat_note, include)
    |> assign(:export_text, build_export_text(socket.assigns.youtube_chapters, socket.assigns.chat_note_value, socket.assigns.streamer_note_value, include, socket.assigns.include_streamer_note))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("toggle_streamer_note", _params, socket) do
    include = !socket.assigns.include_streamer_note

    socket
    |> assign(:include_streamer_note, include)
    |> assign(:export_text, build_export_text(socket.assigns.youtube_chapters, socket.assigns.chat_note_value, socket.assigns.streamer_note_value, socket.assigns.include_chat_note, include))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    send(self(), {:youtube_chapters_modal_closed})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-[9999] flex items-center justify-center p-4"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <!-- Background overlay -->
      <div class="absolute inset-0 bg-black/75 backdrop-blur-sm" phx-click="close_modal" phx-target={@myself}></div>

    <!-- Modal panel -->
      <div class="relative w-full max-w-2xl transform overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 to-gray-900 p-8 shadow-2xl transition-all border border-purple-500/30">
        <!-- Header -->
        <div class="mb-6">
          <h3 class="text-2xl font-bold text-white mb-2" id="modal-title">
            {gettext("Youtube chapters")}
          </h3>
          <p class="text-sm text-gray-400">
            {gettext("Copy and paste these timestamps into your YouTube video description")}
          </p>
        </div>

    <!-- Time Bias Slider -->
        <div class="mb-6">
          <div class="flex items-center justify-between mb-2">
            <label class="text-sm font-medium text-purple-300">
              {gettext("Time Bias")}
            </label>
            <span class="text-sm font-mono text-white bg-purple-600/30 px-3 py-1 rounded-lg">
              {format_bias_display(@time_bias)}
            </span>
          </div>
          <form phx-change="update_bias" phx-target={@myself}>
            <input
              type="range"
              min="0"
              max="600"
              value={@time_bias}
              name="bias"
              class="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-purple-600"
            />
          </form>
          <div class="flex justify-between text-xs text-gray-400 mt-1">
            <span>0:00</span>
            <span>5:00</span>
            <span>10:00</span>
          </div>
        </div>

    <!-- Session score toggles -->
        <div class="mb-6 space-y-2">
          <p class="text-sm font-medium text-purple-300 mb-3">{gettext("Include in export")}</p>
          <label class="flex items-center justify-between cursor-pointer">
            <div class="flex items-center space-x-3">
              <input
                type="checkbox"
                checked={@include_chat_note}
                phx-click="toggle_chat_note"
                phx-target={@myself}
                class="accent-purple-600"
              />
              <span class="text-sm text-gray-300">{gettext("Chat note")}</span>
            </div>
            <span class="text-sm font-mono text-white bg-gray-700 px-2 py-0.5 rounded">
              {format_score(@chat_note_value)}
            </span>
          </label>
          <label class="flex items-center justify-between cursor-pointer">
            <div class="flex items-center space-x-3">
              <input
                type="checkbox"
                checked={@include_streamer_note}
                phx-click="toggle_streamer_note"
                phx-target={@myself}
                class="accent-purple-600"
              />
              <span class="text-sm text-gray-300">{gettext("Streamer note")}</span>
            </div>
            <span class="text-sm font-mono text-white bg-gray-700 px-2 py-0.5 rounded">
              {format_score(@streamer_note_value)}
            </span>
          </label>
        </div>

    <!-- YouTube Chapters Textbox -->
        <div>
          <div class="flex items-center justify-between mb-2">
            <label class="text-sm font-medium text-purple-300">
              {gettext("Chapters")}
            </label>
            <button
              type="button"
              onclick="navigator.clipboard.writeText(document.getElementById('youtube-chapters-text').value)"
              class="text-xs bg-purple-600 hover:bg-purple-700 text-white px-3 py-1 rounded-lg transition-colors flex items-center space-x-1"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                />
              </svg>
              <span>{gettext("Copy")}</span>
            </button>
          </div>
          <textarea
            id="youtube-chapters-text"
            readonly
            rows="12"
            class="w-full bg-black/50 border border-gray-700 rounded-lg p-4 text-white font-mono text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 resize-none"
          >{@export_text}</textarea>
        </div>
      </div>
    </div>
    """
  end

  defp format_bias_display(bias_seconds) do
    "#{div(bias_seconds, 60)}:#{String.pad_leading(to_string(rem(bias_seconds, 60)), 2, "0")}"
  end

  # AIDEV-NOTE: report.session_summary stores keys as strings; guard against nil, AsyncResult, or missing keys
  defp extract_score(nil, _key), do: nil

  defp extract_score(report, key) do
    case Map.get(report, :session_summary) do
      %{^key => score} when is_number(score) -> Float.round(score * 1.0, 1)
      %{^key => score} when is_binary(score) -> score
      _ -> nil
    end
  end

  defp format_score(nil), do: "N/A"
  defp format_score(score), do: "#{score}"

  # AIDEV-NOTE: builds the lines to prepend (chat then streamer) separated from chapters by a blank line
  defp build_export_text(chapters, chat_note_value, streamer_note_value, include_chat, include_streamer) do
    notes =
      [
        if(include_chat and not is_nil(chat_note_value), do: "Chat: #{chat_note_value}", else: nil),
        if(include_streamer and not is_nil(streamer_note_value), do: "Streamer: #{streamer_note_value}", else: nil)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    [notes, chapters]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end
end
