defmodule PremiereEcouteWeb.Sessions.Components.PremiereExport do
  @moduledoc """
  LiveComponent for reviewing speech markers and exporting them as a Premiere Pro
  marker CSV and/or an XMEML sequence file where each speech segment becomes a clipitem.
  """

  use PremiereEcouteWeb, :live_component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.XmemlExport

  # AIDEV-NOTE: {timebase, ntsc} pairs matching xmeml spec. ntsc=TRUE applies 0.01% pulldown.
  @frame_rates [
    {"23.976", 24, "TRUE"},
    {"24", 24, "FALSE"},
    {"25", 25, "FALSE"},
    {"29.97", 30, "TRUE"},
    {"30", 30, "FALSE"}
  ]

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:media_path, fn -> "" end)
      |> assign_new(:frame_rate, fn -> "25" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    send(self(), :premiere_export_modal_closed)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_media_path", %{"value" => path}, socket) do
    {:noreply, assign(socket, :media_path, path)}
  end

  @impl true
  def handle_event("update_frame_rate", %{"frame_rate" => rate}, socket) do
    {:noreply, assign(socket, :frame_rate, rate)}
  end

  @impl true
  def handle_event(
        "export_xml",
        _,
        %{assigns: %{listening_session: session, media_path: media_path, frame_rate: frame_rate}} = socket
      ) do
    {timebase, ntsc} = resolve_rate(frame_rate)
    xml = XmemlExport.build(session, media_path, timebase, ntsc)
    filename = export_filename(session, "xml")

    {:noreply,
     push_event(socket, "download_file", %{
       data: xml,
       filename: filename,
       content_type: "application/xml"
     })}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :frame_rates, @frame_rates)

    ~H"""
    <div
      class="fixed inset-0 z-[9999] flex items-center justify-center p-4"
      aria-labelledby="premiere-modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div class="absolute inset-0 bg-black/75 backdrop-blur-sm" phx-click="close_modal" phx-target={@myself}></div>

      <div class="relative w-full max-w-2xl transform overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 to-gray-900 shadow-2xl border border-violet-500/30">
        <%!-- Header --%>
        <div class="p-6 border-b border-white/10">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h3 class="text-xl font-bold text-white" id="premiere-modal-title">
                {gettext("Export to Premiere")}
              </h3>
              <p class="text-sm text-gray-400 mt-0.5">
                {gettext("Export markers to Premiere Pro")}
              </p>
            </div>
            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="export_xml"
                phx-target={@myself}
                class="flex items-center gap-2 px-3 py-2 rounded-lg bg-violet-600 hover:bg-violet-700 text-white text-sm font-medium transition-colors"
              >
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  />
                </svg>
                {gettext("XMEML")}
              </button>
            </div>
          </div>

          <%!-- XMEML settings --%>
          <div class="flex gap-3 mt-4">
            <div class="flex-1">
              <label class="block text-xs font-medium text-gray-400 mb-1">
                {gettext("Media file path")}
              </label>
              <input
                type="text"
                name="media_path"
                value={@media_path}
                placeholder="/Users/you/Movies/recording.mp4"
                phx-blur="update_media_path"
                phx-target={@myself}
                class="w-full bg-black/50 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm font-mono placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-violet-500"
              />
            </div>
            <div class="w-28">
              <label class="block text-xs font-medium text-gray-400 mb-1">
                {gettext("Frame rate")}
              </label>
              <form phx-change="update_frame_rate" phx-target={@myself}>
                <select
                  name="frame_rate"
                  class="w-full bg-black/50 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-violet-500"
                >
                  <option :for={{label, _tb, _ntsc} <- @frame_rates} value={label} selected={label == @frame_rate}>
                    {label}
                  </option>
                </select>
              </form>
            </div>
          </div>
          <p class="text-xs text-gray-600 mt-1">
            {gettext("Leave path blank to relink manually in Premiere.")}
          </p>
        </div>

        <%!-- Markers list --%>
        <div class="overflow-y-auto max-h-[50vh] p-6 space-y-4">
          <%!-- Track markers --%>
          <div :if={@listening_session.track_markers != []}>
            <p class="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">
              {length(@listening_session.track_markers)} {gettext("tracks")}
            </p>
            <div class="space-y-1.5">
              <div
                :for={
                  {marker, i} <- Enum.with_index(Enum.sort_by(@listening_session.track_markers, & &1.started_at, {:asc, DateTime}), 1)
                }
                class="flex items-center gap-3 rounded-lg bg-white/5 border border-white/10 px-3 py-2"
              >
                <span class="font-mono text-xs text-amber-400 shrink-0">
                  {if @listening_session.started_at,
                    do: ms_to_timestamp(DateTime.diff(marker.started_at, @listening_session.started_at, :millisecond)),
                    else: "—"}
                </span>
                <span class="text-sm text-gray-200 flex-1">
                  {track_label(@listening_session, marker, i)}
                </span>
              </div>
            </div>
          </div>

          <%!-- Speech markers --%>
          <div>
            <p class="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">
              {length(@listening_session.speech_markers)} {gettext("speech segments")}
            </p>
            <div :if={@listening_session.speech_markers == []} class="text-center py-8 text-gray-500 text-sm">
              {gettext("No speech markers recorded.")}
            </div>
            <div class="space-y-1.5">
              <div
                :for={marker <- Enum.sort_by(@listening_session.speech_markers, & &1.start_ms)}
                class="flex items-start gap-3 rounded-lg bg-white/5 border border-white/10 px-3 py-2"
              >
                <div class="flex items-center gap-1 shrink-0 mt-0.5">
                  <span class="font-mono text-xs text-violet-400">{ms_to_timestamp(marker.start_ms)}</span>
                  <span class="text-gray-600 text-xs">→</span>
                  <span class="font-mono text-xs text-violet-300">{ms_to_timestamp(marker.end_ms)}</span>
                  <span class="text-gray-500 text-xs">
                    ({:erlang.float_to_binary((marker.end_ms - marker.start_ms) / 1000, decimals: 1)}s)
                  </span>
                </div>
                <span class="text-sm text-gray-200 flex-1">
                  {marker.text || gettext("no transcription")}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp track_label(%{source: :album, album: album}, marker, i) do
    case album && Enum.find(album.tracks, &(&1.id == marker.track_id)) do
      %{name: name} -> name
      _ -> "Track #{i}"
    end
  end

  defp track_label(%{source: :playlist, playlist: playlist}, marker, i) do
    case playlist && Enum.find(playlist.tracks, &(&1.id == marker.track_id)) do
      %{name: name} -> name
      _ -> "Track #{i}"
    end
  end

  defp track_label(_session, marker, i), do: marker.track_name || "Track #{i}"

  defp resolve_rate(label) do
    @frame_rates
    |> Enum.find({"25", 25, "FALSE"}, fn {l, _, _} -> l == label end)
    |> then(fn {_, tb, ntsc} -> {tb, ntsc} end)
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  defp export_filename(session, ext) do
    title = ListeningSession.title(session) |> String.replace(~r/[^\w\-]/, "_")
    "#{title}_speech_markers_#{Date.utc_today()}.#{ext}"
  end

  defp ms_to_timestamp(ms) do
    total_seconds = div(ms, 1000)
    mm = div(total_seconds, 60)
    ss = rem(total_seconds, 60)
    ms_part = rem(ms, 1000)
    :io_lib.format("~2..0B:~2..0B.~3..0B", [mm, ss, ms_part]) |> IO.iodata_to_binary()
  end
end
