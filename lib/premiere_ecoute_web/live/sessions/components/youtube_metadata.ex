defmodule PremiereEcouteWeb.Sessions.Components.YoutubeMetadata do
  @moduledoc """
  LiveComponent for exporting track markers as YouTube chapter timestamps.
  """

  use PremiereEcouteWeb, :live_component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker
  alias PremiereEcoute.Sessions.Retrospective.Report

  @impl true
  def mount(socket) do
    {:ok, assign(socket, time_bias: 0, options: %{intro: true, notes: true, chapters: true})}
  end

  @impl true
  def update(assigns, socket) do
    session = assigns.listening_session

    socket
    |> assign(assigns)
    |> assign(:listening_session, session)
    |> assign(:report, Report.get_by(session_id: session.id))
    |> assign(:youtube_title, ListeningSession.title(session))
    |> assign(:youtube_chapters, TrackMarker.format_youtube_chapters(session, socket.assigns[:time_bias]))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("update_bias", %{"bias" => bias}, socket) do
    bias_value = String.to_integer(bias)
    chapters = TrackMarker.format_youtube_chapters(socket.assigns.listening_session, bias_value)

    socket
    |> assign(:time_bias, bias_value)
    |> assign(:youtube_chapters, chapters)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("toggle_option", %{"option" => option}, socket) do
    key = String.to_existing_atom(option)
    options = Map.update!(socket.assigns.options, key, &(!&1))
    {:noreply, assign(socket, :options, options)}
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
            {gettext("Youtube")}
          </h3>
          <p class="text-sm text-gray-400">
            {gettext("Copy and paste this title and description into your YouTube video")}
          </p>
        </div>
        
    <!-- Title -->
        <div class="mb-4">
          <div class="flex items-center justify-between mb-2">
            <label class="text-sm font-medium text-purple-300">
              {gettext("Title")}
            </label>
            <button
              type="button"
              onclick="navigator.clipboard.writeText(document.getElementById('youtube-title-text').value)"
              class="text-xs bg-emerald-600 hover:bg-emerald-700 text-white px-3 py-1 rounded-lg transition-colors flex items-center space-x-1"
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
            id="youtube-title-text"
            readonly
            rows="1"
            class="w-full bg-black/50 border border-gray-700 rounded-lg p-4 text-white font-mono text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 resize-none"
          >{gettext("PREMIÈRE ÉCOUTE : \"%{title}\" by %{artist} (React Live)", title: @youtube_title, artist: @listening_session.album.artist)}</textarea>
        </div>
        
    <!-- YouTube Chapters Textbox -->
        <div>
          <div class="flex items-center justify-between mb-2">
            <label class="text-sm font-medium text-purple-300">
              {gettext("Description")}
            </label>
            <div class="flex items-center space-x-3">
              <!-- With Intro toggle -->
              <button
                type="button"
                phx-click="toggle_option"
                phx-value-option="intro"
                phx-target={@myself}
                class={[
                  "text-xs px-3 py-1 rounded-lg transition-colors",
                  if(@options.intro,
                    do: "bg-purple-600 text-white",
                    else: "bg-gray-700 text-gray-400 hover:text-white"
                  )
                ]}
              >
                {gettext("Intro")}
              </button>
              <!-- With Notes toggle -->
              <button
                type="button"
                phx-click="toggle_option"
                phx-value-option="notes"
                phx-target={@myself}
                class={[
                  "text-xs px-3 py-1 rounded-lg transition-colors",
                  if(@options.notes,
                    do: "bg-purple-600 text-white",
                    else: "bg-gray-700 text-gray-400 hover:text-white"
                  )
                ]}
              >
                {gettext("Notes")}
              </button>
              <!-- With Chapters toggle -->
              <button
                type="button"
                phx-click="toggle_option"
                phx-value-option="chapters"
                phx-target={@myself}
                class={[
                  "text-xs px-3 py-1 rounded-lg transition-colors",
                  if(@options.chapters,
                    do: "bg-purple-600 text-white",
                    else: "bg-gray-700 text-gray-400 hover:text-white"
                  )
                ]}
              >
                {gettext("Chapters")}
              </button>
              <button
                type="button"
                onclick="navigator.clipboard.writeText(document.getElementById('youtube-chapters-text').value)"
                class="text-xs bg-emerald-600 hover:bg-emerald-700 text-white px-3 py-1 rounded-lg transition-colors flex items-center space-x-1"
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
          </div>
          <textarea
            id="youtube-chapters-text"
            readonly
            rows="12"
            class="w-full bg-black/50 border border-gray-700 rounded-lg p-4 text-white font-mono text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 resize-none"
          ><%= if @options.intro do %>{gettext("This week I listened and reacted live to the new album \"%{title}\" by %{artist} !", title: @youtube_title, artist: @listening_session.album.artist)}&#013;&#010;&#013;&#010;<% end %><%= if @options.notes do %>{gettext("Streamer score")}: {inspect(@report.session_summary["streamer_score"])}
    {gettext("Viewer score")}: {inspect(@report.session_summary["viewer_score"])}&#013; &#010;<% end %><%= if @options.chapters do %>{@youtube_chapters}<% end %>
          </textarea>
        </div>
        
    <!-- Time Bias Slider -->
        <div class="mt-6">
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
      </div>
    </div>
    """
  end

  defp format_bias_display(bias_seconds) do
    "#{div(bias_seconds, 60)}:#{String.pad_leading(to_string(rem(bias_seconds, 60)), 2, "0")}"
  end
end
