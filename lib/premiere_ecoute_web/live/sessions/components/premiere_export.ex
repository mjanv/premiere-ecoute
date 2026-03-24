defmodule PremiereEcouteWeb.Sessions.Components.PremiereExport do
  @moduledoc """
  LiveComponent for reviewing speech markers and exporting them as a Premiere Pro
  marker CSV and/or an XMEML sequence file where each speech segment becomes a clipitem.
  """

  use PremiereEcouteWeb, :live_component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Sessions.ListeningSession

  # AIDEV-NOTE: timebase=25 (PAL/non-NTSC). All frame values derived from ms * 25 / 1000.
  @timebase 25

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns) |> assign_new(:media_path, fn -> "" end)}
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
  def handle_event("export_csv", _, %{assigns: %{listening_session: session}} = socket) do
    csv = build_premiere_csv(session.speech_markers)
    filename = export_filename(session, "csv")

    {:noreply,
     push_event(socket, "download_file", %{
       data: csv,
       filename: filename,
       content_type: "text/csv"
     })}
  end

  @impl true
  def handle_event("export_xml", _, %{assigns: %{listening_session: session, media_path: media_path}} = socket) do
    xml = build_xmeml(session, media_path)
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
                {gettext("%{count} speech markers", count: length(@listening_session.speech_markers))}
              </p>
            </div>
            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="export_csv"
                phx-target={@myself}
                class="flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-700 hover:bg-gray-600 text-white text-sm font-medium transition-colors"
              >
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  />
                </svg>
                {gettext("CSV")}
              </button>
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

          <%!-- Media path input — required for XMEML relinking --%>
          <div>
            <label class="block text-xs font-medium text-gray-400 mb-1">
              {gettext("Media file path (for XMEML — must match the path Premiere sees)")}
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
            <p class="text-xs text-gray-600 mt-1">
              {gettext("Leave blank to get a placeholder you can relink in Premiere.")}
            </p>
          </div>
        </div>

        <%!-- Markers list --%>
        <div class="overflow-y-auto max-h-[50vh] p-6 space-y-2">
          <div :if={@listening_session.speech_markers == []} class="text-center py-12 text-gray-500">
            {gettext("No speech markers recorded.")}
          </div>
          <div
            :for={marker <- Enum.sort_by(@listening_session.speech_markers, & &1.start_ms)}
            class="flex items-start gap-3 rounded-lg bg-white/5 border border-white/10 p-3"
          >
            <span class="font-mono text-xs text-violet-400 shrink-0 mt-0.5 w-20">
              {ms_to_timestamp(marker.start_ms)}
            </span>
            <span class="font-mono text-xs text-gray-500 shrink-0 mt-0.5">
              +{marker.end_ms - marker.start_ms}ms
            </span>
            <span class="text-sm text-gray-200 flex-1">
              {marker.text || gettext("no transcription")}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # CSV export
  # AIDEV-NOTE: Premiere marker CSV is tab-separated despite .csv extension.
  # Timecode format: HH;MM;SS;FF at @timebase fps.
  # ---------------------------------------------------------------------------

  defp build_premiere_csv(markers) do
    header = "Name\tDescription\tIn\tOut\tDuration\tMarker Type\n"

    rows =
      markers
      |> Enum.sort_by(& &1.start_ms)
      |> Enum.map_join("\n", fn marker ->
        in_tc = ms_to_timecode(marker.start_ms)
        out_tc = ms_to_timecode(marker.end_ms)
        duration_tc = ms_to_timecode(marker.end_ms - marker.start_ms)
        description = marker.text || ""
        "Speech\t#{description}\t#{in_tc}\t#{out_tc}\t#{duration_tc}\tComment"
      end)

    header <> rows
  end

  # ---------------------------------------------------------------------------
  # XMEML export
  # AIDEV-NOTE: xmeml version 5, non-NTSC at @timebase fps.
  # - start/end = clip position on timeline (frames from 0)
  # - in/out    = source media in/out points (frames within the file)
  # - First clipitem declares the <file> in full; subsequent ones reference id only.
  # - pathurl must be file:///... with RFC-2396 percent-encoding.
  # - file duration = total source duration; we use the whole recording length.
  # ---------------------------------------------------------------------------

  defp build_xmeml(%{speech_markers: markers} = session, media_path) do
    sorted = Enum.sort_by(markers, & &1.start_ms)
    total_sequence_frames = sorted |> List.last() |> then(& &1.end_ms) |> ms_to_frames()

    # Total source file duration: use last segment end as a minimum lower bound.
    # Premiere will correct this on relink if the actual file is longer.
    file_duration_frames = total_sequence_frames

    file_name = if media_path == "", do: "recording.mp4", else: Path.basename(media_path)
    path_url = build_pathurl(media_path, file_name)

    clips =
      sorted
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {marker, i} ->
        start_f = ms_to_frames(marker.start_ms)
        end_f = ms_to_frames(marker.end_ms)
        duration_f = end_f - start_f
        label = marker.text || "Speech #{i}"

        file_element =
          if i == 1 do
            "<file id=\"file-1\">" <>
              "<name>#{xml_escape(file_name)}</name>" <>
              "<pathurl>#{path_url}</pathurl>" <>
              "<rate><timebase>#{@timebase}</timebase><ntsc>FALSE</ntsc></rate>" <>
              "<duration>#{file_duration_frames}</duration>" <>
              "</file>"
          else
            "<file id=\"file-1\"/>"
          end

        "<clipitem id=\"clipitem-#{i}\">" <>
          "<name>#{xml_escape(label)}</name>" <>
          "<enabled>TRUE</enabled>" <>
          "<duration>#{duration_f}</duration>" <>
          "<rate><timebase>#{@timebase}</timebase><ntsc>FALSE</ntsc></rate>" <>
          "<start>#{start_f}</start>" <>
          "<end>#{end_f}</end>" <>
          "<in>#{start_f}</in>" <>
          "<out>#{end_f}</out>" <>
          file_element <>
          "</clipitem>"
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE xmeml>
    <xmeml version="5">
      <sequence>
        <name>#{xml_escape(ListeningSession.title(session))} – Speech Markers</name>
        <duration>#{total_sequence_frames}</duration>
        <rate>
          <timebase>#{@timebase}</timebase>
          <ntsc>FALSE</ntsc>
        </rate>
        <media>
          <video>
            <track>
    #{clips}
            </track>
          </video>
        </media>
      </sequence>
    </xmeml>
    """
  end

  defp build_pathurl("", file_name), do: "file:///#{percent_encode(file_name)}"

  defp build_pathurl(path, _file_name) do
    # Normalise: ensure absolute path, then encode
    clean = path |> String.trim() |> String.replace_leading("file:///", "") |> String.replace_leading("file://localhost/", "")
    "file:///#{percent_encode(clean)}"
  end

  # Percent-encode path segments per RFC 2396 (keep / separators unencoded)
  defp percent_encode(path) do
    path
    |> String.split("/")
    |> Enum.map(&URI.encode/1)
    |> Enum.join("/")
  end

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  defp export_filename(session, ext) do
    title = ListeningSession.title(session) |> String.replace(~r/[^\w\-]/, "_")
    "#{title}_speech_markers_#{Date.utc_today()}.#{ext}"
  end

  defp ms_to_frames(ms), do: div(ms * @timebase, 1000)

  defp ms_to_timecode(ms) do
    total_seconds = div(ms, 1000)
    frames = div(rem(ms, 1000) * @timebase, 1000)
    hh = div(total_seconds, 3600)
    mm = div(rem(total_seconds, 3600), 60)
    ss = rem(total_seconds, 60)
    :io_lib.format("~2..0B;~2..0B;~2..0B;~2..0B", [hh, mm, ss, frames]) |> IO.iodata_to_binary()
  end

  defp ms_to_timestamp(ms) do
    total_seconds = div(ms, 1000)
    mm = div(total_seconds, 60)
    ss = rem(total_seconds, 60)
    ms_part = rem(ms, 1000)
    :io_lib.format("~2..0B:~2..0B.~3..0B", [mm, ss, ms_part]) |> IO.iodata_to_binary()
  end
end
