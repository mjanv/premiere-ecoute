defmodule PremiereEcouteWeb.Sessions.Components.YoutubeChaptersModal do
  @moduledoc """
  LiveComponent for exporting track markers as YouTube chapter timestamps.
  """

  use PremiereEcouteWeb, :live_component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker

  @impl true
  def mount(socket) do
    {:ok, assign(socket, time_bias: 0)}
  end

  @impl true
  def update(assigns, socket) do
    session = assigns.listening_session
    report = assigns[:report]
    time_bias = socket.assigns[:time_bias] || 0

    socket
    |> assign(assigns)
    |> assign(:listening_session, session)
    |> assign(:report, report)
    |> assign(:time_bias, time_bias)
    |> assign(:youtube_chapters, build_export_text(session, report, time_bias))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("update_bias", %{"bias" => bias}, socket) do
    bias_value = String.to_integer(bias)

    export_text =
      build_export_text(socket.assigns.listening_session, socket.assigns.report, bias_value)

    socket
    |> assign(:time_bias, bias_value)
    |> assign(:youtube_chapters, export_text)
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
          >{@youtube_chapters}</textarea>
        </div>
      </div>
    </div>
    """
  end

  # AIDEV-NOTE: assembles full YouTube export text; scores section is conditional on
  # numeric vote mode and a non-nil report with numeric scores.
  defp build_export_text(session, report, time_bias) do
    chapters = TrackMarker.format_youtube_chapters(session, time_bias)
    chapters_header = gettext("Track chapters:")
    scores_header = build_scores_header(session, report)

    case scores_header do
      nil -> "#{chapters_header}\n\n#{chapters}"
      scores -> "#{scores}\n\n#{chapters_header}\n\n#{chapters}"
    end
  end

  defp build_scores_header(_session, report) when not is_map(report), do: nil

  defp build_scores_header(%{vote_options: vote_options} = _session, %{session_summary: summary})
       when is_map(summary) do
    if numeric_vote_mode?(vote_options) do
      viewer_score = summary["viewer_score"]
      streamer_score = summary["streamer_score"]

      if is_number(viewer_score) or is_number(streamer_score) do
        denominator = vote_denominator(vote_options)
        locale = Gettext.get_locale(PremiereEcoute.Gettext)

        [
          format_score_line(gettext("Chat note"), viewer_score, denominator, locale),
          format_score_line(gettext("Streamer note"), streamer_score, denominator, locale)
        ]
        |> Enum.reject(&is_nil/1)
        |> case do
          [] -> nil
          lines -> Enum.join(lines, "\n")
        end
      else
        nil
      end
    else
      nil
    end
  end

  defp build_scores_header(_session, _report), do: nil

  defp numeric_vote_mode?(["0" | _]), do: true
  defp numeric_vote_mode?(["1" | _]), do: true
  defp numeric_vote_mode?(_), do: false

  # AIDEV-NOTE: max of vote_options gives the denominator (e.g. 10 for 0-10, 5 for 1-5).
  defp vote_denominator(vote_options) do
    vote_options |> Enum.map(&String.to_integer/1) |> Enum.max()
  end

  defp format_score_line(_label, nil, _denom, _locale), do: nil
  defp format_score_line(_label, score, _denom, _locale) when not is_number(score), do: nil

  defp format_score_line(label, score, denominator, locale) do
    formatted = score |> Float.round(1) |> format_decimal(locale)
    "#{label} : #{formatted}/#{denominator}"
  end

  # AIDEV-NOTE: French locale uses comma as decimal separator per spec.
  defp format_decimal(value, "fr") when is_float(value),
    do: value |> to_string() |> String.replace(".", ",")

  defp format_decimal(value, _locale) when is_float(value), do: to_string(value)

  defp format_bias_display(bias_seconds) do
    "#{div(bias_seconds, 60)}:#{String.pad_leading(to_string(rem(bias_seconds, 60)), 2, "0")}"
  end
end
