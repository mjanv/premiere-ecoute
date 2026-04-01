defmodule PremiereEcoute.Sessions.ListeningSession.XmemlExport do
  @moduledoc """
  Generates XMEML v4 sequences importable by Adobe Premiere Pro 26+.

  Produces two video tracks:
  - V1 (speech): one clipitem per speech marker, labeled "Clip NNN", transcription in marker comment
  - V2 (chapters): one clipitem per track marker, labeled with track name (only when track markers exist)

  Each video clipitem has matching exploded audio clipitems (ch1 + ch2) linked by <link> elements.
  Each video track declares its own <file> element (independent per-track file declarations avoid
  cross-track idref resolution failures in Premiere's XMEML importer).

  ## ppro ticks

  Premiere internally uses a 254016000000 ticks/second clock. Frame N at timebase T corresponds to
  N * 254016000000 / T ticks. We compute pproTicksOut per clipitem from the source out-point.

  ## File IDs

  - file-1: declared in speech track (clipitem-1), referenced by all speech clipitems + all audio clipitems
  - file-2: declared fresh in chapter track (clipitem-10+), referenced within chapter track only

  Chapter track uses an independent file declaration per first clipitem to avoid cross-track idref failures.
  """

  alias PremiereEcoute.Sessions.ListeningSession

  # AIDEV-NOTE: title/1 accepts both ListeningSession structs and plain maps (used in tests)

  # AIDEV-NOTE: ppro internal clock = 254016000000 ticks/second
  @ppro_ticks_per_second 254_016_000_000

  @sequence_attrs ~s(TL.SQAudioVisibleBase="0" TL.SQVideoVisibleBase="0" TL.SQVisibleBaseTime="0" ) <>
                    ~s(TL.SQAVDividerPosition="0.5" TL.SQHideShyTracks="0" TL.SQHeaderWidth="204" ) <>
                    ~s(MZ.Sequence.PreviewFrameSizeHeight="1080" MZ.Sequence.PreviewFrameSizeWidth="1920" ) <>
                    ~s(MZ.Sequence.AudioTimeDisplayFormat="200" ) <>
                    ~s(MZ.Sequence.EditingModeGUID="9678af98-a7b7-4bdb-b477-7ac9c8df4a4e" ) <>
                    ~s(MZ.Sequence.VideoTimeDisplayFormat="110" ) <>
                    ~s(MZ.WorkOutPoint="21547094400000" MZ.WorkInPoint="0" explodedTracks="true")

  @doc """
  Builds an XMEML v4 sequence string from a ListeningSession.

  ## Parameters
  - `session` - ListeningSession with preloaded speech_markers and track_markers
  - `media_path` - absolute path to the source video file (empty string = relink manually)
  - `timebase` - frame rate integer (e.g. 25)
  - `ntsc` - "TRUE" or "FALSE"
  - `uuid` - sequence UUID string (injectable for deterministic tests)
  - `source_duration` - source file duration in frames (optional, defaults to sequence duration)
  """
  @spec build(ListeningSession.t(), String.t(), integer(), String.t(), String.t(), integer() | nil) :: String.t()
  def build(session, media_path, timebase, ntsc, uuid \\ generate_uuid(), source_duration \\ nil) do
    sorted_speech = Enum.sort_by(session.speech_markers, & &1.start_ms)
    sorted_tracks = Enum.sort_by(session.track_markers, & &1.started_at, {:asc, DateTime})

    speech_end_ms = if sorted_speech != [], do: List.last(sorted_speech).end_ms, else: 0

    track_end_ms =
      if sorted_tracks != [] && not is_nil(session.started_at) do
        DateTime.diff(List.last(sorted_tracks).started_at, session.started_at, :millisecond)
      else
        0
      end

    total_ms = max(speech_end_ms, track_end_ms)
    total_frames = ms_to_frames(total_ms, timebase)

    # AIDEV-NOTE: source_duration is the actual file length in frames (independent of sequence length).
    # Defaults to total_frames when unknown — sufficient for Premiere to link media.
    file_source_duration = source_duration || total_frames

    file_name = if media_path == "", do: "recording.mp4", else: Path.basename(media_path)
    path_url = build_pathurl(media_path, file_name)

    speech_video_track = build_speech_video_track(sorted_speech, file_name, path_url, file_source_duration, timebase, ntsc)

    chapter_video_track =
      build_chapter_video_track(sorted_tracks, session, file_name, path_url, file_source_duration, timebase, ntsc,
        speech_count: length(sorted_speech)
      )

    audio_tracks = build_audio_tracks(sorted_speech, file_name, file_source_duration, timebase, ntsc)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <xmeml version="4">
      <sequence id="sequence-1" #{@sequence_attrs}>
        <uuid>#{uuid}</uuid>
        <duration>#{total_frames}</duration>
        <rate>
          <timebase>#{timebase}</timebase>
          <ntsc>#{ntsc}</ntsc>
        </rate>
        <name>#{xml_escape(session_title(session))}</name>
        <media>
          <video>
            #{video_format(timebase, ntsc)}
            #{speech_video_track}
            #{chapter_video_track}
          </video>
          <audio>
            <numOutputChannels>2</numOutputChannels>
            <format>
              <samplecharacteristics>
                <depth>16</depth>
                <samplerate>48000</samplerate>
              </samplecharacteristics>
            </format>
            #{audio_outputs()}
            #{audio_tracks}
          </audio>
        </media>
        <timecode>
          <rate>
            <timebase>#{timebase}</timebase>
            <ntsc>#{ntsc}</ntsc>
          </rate>
          <string>00:00:00:00</string>
          <frame>0</frame>
          <displayformat>NDF</displayformat>
        </timecode>
        <labels>
          <label2>Forest</label2>
        </labels>
        <logginginfo>
          <description/>
          <scene/>
          <shottake/>
          <lognote/>
          <good/>
          <originalvideofilename/>
          <originalaudiofilename/>
        </logginginfo>
      </sequence>
    </xmeml>
    """
    |> String.trim()
  end

  defp session_title(%ListeningSession{} = session), do: ListeningSession.title(session)
  defp session_title(%{name: name}), do: name || ""

  # ---------------------------------------------------------------------------
  # Video tracks
  # ---------------------------------------------------------------------------

  defp build_speech_video_track(sorted_speech, file_name, path_url, source_duration, timebase, ntsc) do
    n = length(sorted_speech)

    clips =
      sorted_speech
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {marker, i} ->
        start_f = ms_to_frames(marker.start_ms, timebase)
        end_f = ms_to_frames(marker.end_ms, timebase)
        name = "Clip #{String.pad_leading(to_string(i), 3, "0")}"

        # Audio link targets: ch1 = clipitem-(n+i), ch2 = clipitem-(2n+i)
        audio_ch1_id = "clipitem-#{n + i}"
        audio_ch2_id = "clipitem-#{2 * n + i}"

        file_xml =
          if i == 1 do
            full_file_xml("file-1", file_name, path_url, source_duration, timebase, ntsc)
          else
            ~s(<file id="file-1"/>)
          end

        """
                <clipitem id="clipitem-#{i}">
                  <masterclipid>masterclip-1</masterclipid>
                  <name>#{xml_escape(name)}</name>
                  <enabled>TRUE</enabled>
                  <duration>#{source_duration}</duration>
                  #{rate_xml(timebase, ntsc)}
                  <start>#{start_f}</start>
                  <end>#{end_f}</end>
                  <in>#{start_f}</in>
                  <out>#{end_f}</out>
                  <pproTicksIn>#{ppro_ticks(start_f, timebase)}</pproTicksIn>
                  <pproTicksOut>#{ppro_ticks(end_f, timebase)}</pproTicksOut>
                  <alphatype>none</alphatype>
                  <pixelaspectratio>square</pixelaspectratio>
                  <anamorphic>FALSE</anamorphic>
                  #{file_xml}
                  #{link_xml("clipitem-#{i}", "video", 1, i)}
                  #{link_xml(audio_ch1_id, "audio", 1, i)}
                  #{link_xml(audio_ch2_id, "audio", 2, i)}
                  <marker>
                    <name>#{xml_escape(name)}</name>
                    <comment>#{xml_escape(marker.text || "")}</comment>
                    <in>#{start_f}</in>
                    <out>#{end_f}</out>
                  </marker>
                  #{logging_info()}
                  #{color_info()}
                  <labels><label2>Iris</label2></labels>
                </clipitem>
        """
      end)

    """
            <track TL.SQTrackShy="0" TL.SQTrackExpandedHeight="41" TL.SQTrackExpanded="0" MZ.TrackTargeted="1">
              #{clips}
              <enabled>TRUE</enabled>
              <locked>FALSE</locked>
            </track>
    """
  end

  defp build_chapter_video_track([], _session, _file_name, _path_url, _source_duration, _timebase, _ntsc, _opts),
    do: ""

  defp build_chapter_video_track(sorted_tracks, session, file_name, path_url, source_duration, timebase, ntsc, opts) do
    speech_count = Keyword.fetch!(opts, :speech_count)
    # Chapter clipitems start after speech (n) + audio ch1 (n) + audio ch2 (n) = 3n
    base_id = 3 * speech_count + 1

    last_end_ms =
      if is_nil(session.started_at) do
        0
      else
        DateTime.diff(List.last(sorted_tracks).started_at, session.started_at, :millisecond)
      end

    clips =
      sorted_tracks
      |> Enum.with_index(0)
      |> Enum.map_join("\n", fn {marker, idx} ->
        i = idx + 1
        clipitem_id = "clipitem-#{base_id + idx}"

        start_ms =
          if is_nil(session.started_at),
            do: 0,
            else: DateTime.diff(marker.started_at, session.started_at, :millisecond)

        next = Enum.at(sorted_tracks, i)

        end_ms =
          if next && not is_nil(session.started_at),
            do: DateTime.diff(next.started_at, session.started_at, :millisecond),
            else: last_end_ms

        start_f = ms_to_frames(start_ms, timebase)
        end_f = ms_to_frames(end_ms, timebase)
        label = track_label(session, marker, i)

        # AIDEV-NOTE: each chapter clipitem gets its own full file declaration to avoid
        # cross-track idref failures in Premiere's XMEML importer.
        file_id = "file-#{i + 1}"

        file_xml = full_file_xml(file_id, file_name, path_url, source_duration, timebase, ntsc)

        """
                <clipitem id="#{clipitem_id}">
                  <masterclipid>masterclip-1</masterclipid>
                  <name>#{xml_escape(label)}</name>
                  <enabled>TRUE</enabled>
                  <duration>#{source_duration}</duration>
                  #{rate_xml(timebase, ntsc)}
                  <start>#{start_f}</start>
                  <end>#{end_f}</end>
                  <in>#{start_f}</in>
                  <out>#{end_f}</out>
                  <pproTicksIn>#{ppro_ticks(start_f, timebase)}</pproTicksIn>
                  <pproTicksOut>#{ppro_ticks(end_f, timebase)}</pproTicksOut>
                  <alphatype>none</alphatype>
                  <pixelaspectratio>square</pixelaspectratio>
                  <anamorphic>FALSE</anamorphic>
                  #{file_xml}
                  <marker>
                    <name>#{xml_escape(label)}</name>
                    <comment>#{xml_escape(label)}</comment>
                    <in>#{start_f}</in>
                    <out>#{end_f}</out>
                  </marker>
                  #{logging_info()}
                  #{color_info()}
                  <labels><label2>Lavender</label2></labels>
                </clipitem>
        """
      end)

    """
            <track TL.SQTrackShy="0" TL.SQTrackExpandedHeight="41" TL.SQTrackExpanded="0" MZ.TrackTargeted="0">
              #{clips}
              <enabled>TRUE</enabled>
              <locked>FALSE</locked>
            </track>
    """
  end

  # ---------------------------------------------------------------------------
  # Audio tracks (exploded stereo: ch1 + ch2, one clipitem per speech segment per channel)
  # ---------------------------------------------------------------------------

  defp build_audio_tracks(sorted_speech, file_name, source_duration, timebase, ntsc) do
    n = length(sorted_speech)

    build_channel = fn channel_index, track_index, output_channel ->
      clips =
        sorted_speech
        |> Enum.with_index(1)
        |> Enum.map_join("\n", fn {marker, i} ->
          start_f = ms_to_frames(marker.start_ms, timebase)
          end_f = ms_to_frames(marker.end_ms, timebase)

          # audio ch1 clipitem ids = n+i, ch2 = 2n+i
          clipitem_id = "clipitem-#{track_index * n + i}"
          audio_ch1_id = "clipitem-#{n + i}"
          audio_ch2_id = "clipitem-#{2 * n + i}"

          """
                  <clipitem id="#{clipitem_id}" premiereChannelType="stereo">
                    <masterclipid>masterclip-1</masterclipid>
                    <name>#{xml_escape(file_name)}</name>
                    <enabled>TRUE</enabled>
                    <duration>#{source_duration}</duration>
                    #{rate_xml(timebase, ntsc)}
                    <start>#{start_f}</start>
                    <end>#{end_f}</end>
                    <in>#{start_f}</in>
                    <out>#{end_f}</out>
                    <pproTicksIn>#{ppro_ticks(start_f, timebase)}</pproTicksIn>
                    <pproTicksOut>#{ppro_ticks(end_f, timebase)}</pproTicksOut>
                    <file id="file-1"/>
                    <sourcetrack>
                      <mediatype>audio</mediatype>
                      <trackindex>#{channel_index}</trackindex>
                    </sourcetrack>
                    #{link_xml("clipitem-#{i}", "video", 1, i)}
                    #{link_xml(audio_ch1_id, "audio", 1, i)}
                    #{link_xml(audio_ch2_id, "audio", 2, i)}
                    #{logging_info()}
                    #{color_info()}
                    <labels><label2>Iris</label2></labels>
                  </clipitem>
          """
        end)

      """
              <track TL.SQTrackAudioKeyframeStyle="0" TL.SQTrackShy="0" TL.SQTrackExpandedHeight="41" TL.SQTrackExpanded="0" MZ.TrackTargeted="1" PannerCurrentValue="0.5" PannerIsInverted="true" PannerStartKeyframe="-91445760000000000,0.5,0,0,0,0,0,0" PannerName="Balance" currentExplodedTrackIndex="#{channel_index - 1}" totalExplodedTrackCount="2" premiereTrackType="Mono">
                #{clips}
                <enabled>TRUE</enabled>
                <locked>FALSE</locked>
                <outputchannelindex>#{output_channel}</outputchannelindex>
              </track>
      """
    end

    build_channel.(1, 1, 1) <> build_channel.(2, 2, 2)
  end

  # ---------------------------------------------------------------------------
  # XML fragments
  # ---------------------------------------------------------------------------

  defp video_format(timebase, ntsc) do
    """
            <format>
              <samplecharacteristics>
                #{rate_xml(timebase, ntsc)}
                <codec>
                  <name>Apple ProRes 422</name>
                  <appspecificdata>
                    <appname>Final Cut Pro</appname>
                    <appmanufacturer>Apple Inc.</appmanufacturer>
                    <appversion>7.0</appversion>
                    <data>
                      <qtcodec>
                        <codecname>Apple ProRes 422</codecname>
                        <codectypename>Apple ProRes 422</codectypename>
                        <codectypecode>apcn</codectypecode>
                        <codecvendorcode>appl</codecvendorcode>
                        <spatialquality>1024</spatialquality>
                        <temporalquality>0</temporalquality>
                        <keyframerate>0</keyframerate>
                        <datarate>0</datarate>
                      </qtcodec>
                    </data>
                  </appspecificdata>
                </codec>
                <width>1920</width>
                <height>1080</height>
                <anamorphic>FALSE</anamorphic>
                <pixelaspectratio>square</pixelaspectratio>
                <fielddominance>none</fielddominance>
                <colordepth>24</colordepth>
              </samplecharacteristics>
            </format>
    """
  end

  defp full_file_xml(file_id, file_name, path_url, source_duration, timebase, ntsc) do
    """
    <file id="#{file_id}">
                    <name>#{xml_escape(file_name)}</name>
                    <pathurl>#{path_url}</pathurl>
                    #{rate_xml(timebase, ntsc)}
                    <duration>#{source_duration}</duration>
                    <timecode>
                      #{rate_xml(timebase, ntsc)}
                      <string>00:00:00:00</string>
                      <frame>0</frame>
                      <displayformat>NDF</displayformat>
                    </timecode>
                    <media>
                      <video>
                        <samplecharacteristics>
                          #{rate_xml(timebase, ntsc)}
                          <width>1920</width>
                          <height>1080</height>
                          <anamorphic>FALSE</anamorphic>
                          <pixelaspectratio>square</pixelaspectratio>
                          <fielddominance>none</fielddominance>
                        </samplecharacteristics>
                      </video>
                      <audio>
                        <samplecharacteristics>
                          <depth>16</depth>
                          <samplerate>48000</samplerate>
                        </samplecharacteristics>
                        <channelcount>2</channelcount>
                      </audio>
                    </media>
                  </file>
    """
  end

  defp link_xml(clipref, mediatype, trackindex, clipindex) do
    """
    <link>
                    <linkclipref>#{clipref}</linkclipref>
                    <mediatype>#{mediatype}</mediatype>
                    <trackindex>#{trackindex}</trackindex>
                    <clipindex>#{clipindex}</clipindex>
                  </link>
    """
  end

  defp audio_outputs do
    """
            <outputs>
              <group>
                <index>1</index>
                <numchannels>1</numchannels>
                <downmix>0</downmix>
                <channel><index>1</index></channel>
              </group>
              <group>
                <index>2</index>
                <numchannels>1</numchannels>
                <downmix>0</downmix>
                <channel><index>2</index></channel>
              </group>
            </outputs>
    """
  end

  defp logging_info do
    """
    <logginginfo>
                    <description/>
                    <scene/>
                    <shottake/>
                    <lognote/>
                    <good/>
                    <originalvideofilename/>
                    <originalaudiofilename/>
                  </logginginfo>
    """
  end

  defp color_info do
    """
    <colorinfo>
                    <lut/>
                    <lut1/>
                    <asc_sop/>
                    <asc_sat/>
                    <lut2/>
                  </colorinfo>
    """
  end

  defp rate_xml(timebase, ntsc) do
    "<rate><timebase>#{timebase}</timebase><ntsc>#{ntsc}</ntsc></rate>"
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

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

  defp ms_to_frames(ms, timebase), do: div(ms * timebase, 1000)

  defp ppro_ticks(frames, timebase),
    do: div(frames * @ppro_ticks_per_second, timebase)

  defp build_pathurl("", file_name), do: "file:///#{percent_encode(file_name)}"

  defp build_pathurl(path, _file_name) do
    clean =
      path
      |> String.trim()
      |> String.replace_leading("file:///", "")
      |> String.replace_leading("file://localhost/", "")

    "file://localhost/#{percent_encode(clean)}"
  end

  # AIDEV-NOTE: URI.encode/1 does not encode ":" but Premiere Pro expects "C%3a" for Windows drive letters.
  defp percent_encode(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", fn segment ->
      segment
      |> URI.encode()
      |> String.replace(":", "%3a")
    end)
  end

  defp xml_escape(nil), do: ""

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp generate_uuid, do: UUID.uuid4()
end
