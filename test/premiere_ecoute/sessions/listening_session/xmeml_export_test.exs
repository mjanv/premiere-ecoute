defmodule PremiereEcoute.Sessions.ListeningSession.XmemlExportTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Sessions.ListeningSession.SpeechMarker
  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker
  alias PremiereEcoute.Sessions.ListeningSession.XmemlExport

  # Reference files produced by iterating with Premiere Pro 26.0.2
  @fixture_speech "test/support/premiere/test_speech.xml"
  @fixture_speech_chapters "test/support/premiere/test_speech_chapters.xml"

  # Data matching the reference fixtures exactly:
  # - 25fps NDF
  # - source file: Sample Media Clip 8.mp4 at the standard Windows sample media path
  # - 3 speech clips at timeline frames 321-361, 391-434, 496-534
  # - source duration = 1000 frames
  # - fixed UUID so output is deterministic
  @fixed_uuid "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  @media_path "C:/Users/Public/Documents/Adobe/Premiere Pro/26.0/Sample Media/Sample Media Clip 8.mp4"
  @timebase 25
  @ntsc "FALSE"

  # Speech markers: start_ms/end_ms chosen so ms_to_frames gives the reference frame values
  # frame = ms * 25 / 1000  →  321f = 12840ms, 361f = 14440ms, 391f = 15640ms, 434f = 17360ms, 496f = 19840ms, 534f = 21360ms
  @speech_markers [
    %SpeechMarker{start_ms: 12_840, end_ms: 14_440, text: ~s(He said: "welcome to the stream")},
    %SpeechMarker{start_ms: 15_640, end_ms: 17_360, text: "She said: \"let's go\""},
    %SpeechMarker{start_ms: 19_840, end_ms: 21_360, text: "Background music starts"}
  ]

  # Track markers: started_at chosen so frame offsets = 321, 496 relative to session.started_at
  # 321f @ 25fps = 12840ms, 496f = 19840ms
  @session_started_at ~U[2024-01-01 00:00:00Z]
  @track_markers [
    %TrackMarker{track_name: "Chapter 01 - Introduction", started_at: DateTime.add(@session_started_at, 12_840, :millisecond)},
    %TrackMarker{track_name: "Chapter 02 - Conclusion", started_at: DateTime.add(@session_started_at, 19_840, :millisecond)}
  ]

  defp speech_only_session do
    %{
      speech_markers: @speech_markers,
      track_markers: [],
      started_at: @session_started_at,
      name: "Millenium_Fixed_Final",
      source: :free,
      album: nil,
      playlist: nil
    }
  end

  defp speech_and_chapters_session do
    %{speech_only_session() | track_markers: @track_markers}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp parse_xml(xml_string) do
    xml_string
    |> String.to_charlist()
    |> :xmerl_scan.string(quiet: true)
    |> elem(0)
  end

  defp xpath(doc, path) do
    :xmerl_xpath.string(String.to_charlist(path), doc)
  end

  defp text_value(elements) when is_list(elements) do
    elements
    |> Enum.map(&text_value/1)
  end

  defp text_value({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    children
    |> Enum.filter(&match?({:xmlText, _, _, _, _, _}, &1))
    |> Enum.map_join(fn {:xmlText, _, _, _, value, _} -> to_string(value) end)
  end

  defp text_value({:xmlText, _, _, _, value, _}), do: to_string(value)

  defp attr_value({:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _}, attr_name) do
    attrs
    |> Enum.find(fn {:xmlAttribute, name, _, _, _, _, _, _, _, _} -> name == attr_name end)
    |> then(fn {:xmlAttribute, _, _, _, _, _, _, _, value, _} -> to_string(value) end)
  end

  # ---------------------------------------------------------------------------
  # Tests: speech-only fixture
  # ---------------------------------------------------------------------------

  describe "build/5 - speech only" do
    setup do
      session = speech_only_session()
      xml = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000)
      ref = File.read!(@fixture_speech)
      {:ok, xml: xml, ref: ref}
    end

    test "produces valid XML", %{xml: xml} do
      assert {:xmlElement, :xmeml, _, _, _, _, _, _, _, _, _, _} = parse_xml(xml)
    end

    test "xmeml version is 4", %{xml: xml} do
      doc = parse_xml(xml)
      [el] = xpath(doc, "/xmeml")
      assert attr_value(el, :version) == "4"
    end

    test "sequence uuid matches reference", %{xml: xml, ref: ref} do
      doc = parse_xml(xml)
      ref_doc = parse_xml(ref)

      assert text_value(xpath(doc, "/xmeml/sequence/uuid")) ==
               text_value(xpath(ref_doc, "/xmeml/sequence/uuid"))
    end

    test "sequence duration matches reference", %{xml: xml, ref: ref} do
      doc = parse_xml(xml)
      ref_doc = parse_xml(ref)

      assert text_value(xpath(doc, "/xmeml/sequence/duration")) ==
               text_value(xpath(ref_doc, "/xmeml/sequence/duration"))
    end

    test "has exactly 1 video track (no chapter track)", %{xml: xml} do
      doc = parse_xml(xml)
      tracks = xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(tracks) == 1
    end

    test "speech track has 3 clipitems", %{xml: xml} do
      doc = parse_xml(xml)
      clips = xpath(doc, "/xmeml/sequence/media/video/track/clipitem")
      assert length(clips) == 3
    end

    test "clipitem ids match reference", %{xml: xml, ref: ref} do
      doc = parse_xml(xml)
      ref_doc = parse_xml(ref)

      ids = xpath(doc, "/xmeml/sequence/media/video/track/clipitem") |> Enum.map(&attr_value(&1, :id))
      ref_ids = xpath(ref_doc, "/xmeml/sequence/media/video/track/clipitem") |> Enum.map(&attr_value(&1, :id))

      assert ids == ref_ids
    end

    test "first clipitem start/end/in/out match reference", %{xml: xml, ref: ref} do
      doc = parse_xml(xml)
      ref_doc = parse_xml(ref)

      for field <- ~w(start end in out) do
        path = "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/#{field}"
        assert text_value(xpath(doc, path)) == text_value(xpath(ref_doc, path))
      end
    end

    test "clip names are Clip 001, Clip 002, Clip 003", %{xml: xml} do
      doc = parse_xml(xml)
      names = xpath(doc, "/xmeml/sequence/media/video/track/clipitem/name") |> text_value()
      assert names == ["Clip 001", "Clip 002", "Clip 003"]
    end

    test "marker comments contain transcription text", %{xml: xml} do
      doc = parse_xml(xml)
      comments = xpath(doc, "/xmeml/sequence/media/video/track/clipitem/marker/comment") |> text_value()
      assert Enum.at(comments, 0) =~ "welcome to the stream"
      assert Enum.at(comments, 1) =~ "let's go"
      assert Enum.at(comments, 2) == "Background music starts"
    end

    test "first clipitem declares file-1 fully, others reference it", %{xml: xml} do
      doc = parse_xml(xml)

      # clipitem-1 should have a full file element with pathurl
      [pathurl] = xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/file/pathurl")
      assert text_value(pathurl) =~ "Sample%20Media%20Clip%208.mp4"

      # clipitem-2 should have a self-referencing file element (no pathurl child)
      pathrefs2 = xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-2']/file/pathurl")
      assert pathrefs2 == []
    end

    test "has 2 audio tracks", %{xml: xml} do
      doc = parse_xml(xml)
      tracks = xpath(doc, "/xmeml/sequence/media/audio/track")
      assert length(tracks) == 2
    end

    test "audio tracks have 3 clipitems each", %{xml: xml} do
      doc = parse_xml(xml)
      tracks = xpath(doc, "/xmeml/sequence/media/audio/track")

      for track <- tracks do
        clips = xpath(track, "clipitem")
        assert length(clips) == 3
      end
    end

    test "pathurl uses file://localhost/ format for Windows paths", %{xml: xml} do
      doc = parse_xml(xml)
      [pathurl] = xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/file/pathurl")
      assert text_value(pathurl) =~ "file://localhost/"
    end

    test "pathurl encodes colon in drive letter as %3a", %{xml: xml} do
      doc = parse_xml(xml)
      [pathurl] = xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/file/pathurl")
      assert text_value(pathurl) =~ "C%3a"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: speech + chapters fixture
  # ---------------------------------------------------------------------------

  describe "build/5 - speech with chapters" do
    setup do
      session = speech_and_chapters_session()
      xml = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000)
      ref = File.read!(@fixture_speech_chapters)
      {:ok, xml: xml, ref: ref}
    end

    test "produces valid XML", %{xml: xml} do
      assert {:xmlElement, :xmeml, _, _, _, _, _, _, _, _, _, _} = parse_xml(xml)
    end

    test "has 2 video tracks", %{xml: xml} do
      doc = parse_xml(xml)
      tracks = xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(tracks) == 2
    end

    test "speech track (V1) has 3 clipitems", %{xml: xml} do
      doc = parse_xml(xml)
      [speech_track | _] = xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(xpath(speech_track, "clipitem")) == 3
    end

    test "chapter track (V2) has 2 clipitems", %{xml: xml} do
      doc = parse_xml(xml)
      [_, chapter_track] = xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(xpath(chapter_track, "clipitem")) == 2
    end

    test "chapter clipitem names match track names", %{xml: xml} do
      doc = parse_xml(xml)
      [_, chapter_track] = xpath(doc, "/xmeml/sequence/media/video/track")
      names = xpath(chapter_track, "clipitem/name") |> text_value()
      assert names == ["Chapter 01 - Introduction", "Chapter 02 - Conclusion"]
    end

    test "chapter clipitems have independent file declarations (no cross-track idref)", %{xml: xml} do
      doc = parse_xml(xml)
      [_, chapter_track] = xpath(doc, "/xmeml/sequence/media/video/track")
      clips = xpath(chapter_track, "clipitem")

      for clip <- clips do
        [file] = xpath(clip, "file")
        file_id = attr_value(file, :id)
        assert file_id != "file-1", "Chapter track must not reuse file-1 from speech track"
        pathrls = xpath(file, "pathurl")
        assert length(pathrls) == 1, "Chapter clipitem must have full file declaration with pathurl"
      end
    end

    test "chapter track clipitem start frames match reference", %{xml: xml, ref: ref} do
      doc = parse_xml(xml)
      ref_doc = parse_xml(ref)

      for id <- ["clipitem-10", "clipitem-11"] do
        path = "/xmeml/sequence/media/video/track/clipitem[@id='#{id}']/start"
        assert text_value(xpath(doc, path)) == text_value(xpath(ref_doc, path))
      end
    end

    test "chapter labels are Lavender", %{xml: xml} do
      doc = parse_xml(xml)
      [_, chapter_track] = xpath(doc, "/xmeml/sequence/media/video/track")
      labels = xpath(chapter_track, "clipitem/labels/label2") |> text_value()
      assert Enum.all?(labels, &(&1 == "Lavender"))
    end

    test "speech labels are Iris", %{xml: xml} do
      doc = parse_xml(xml)
      [speech_track | _] = xpath(doc, "/xmeml/sequence/media/video/track")
      labels = xpath(speech_track, "clipitem/labels/label2") |> text_value()
      assert Enum.all?(labels, &(&1 == "Iris"))
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: edge cases
  # ---------------------------------------------------------------------------

  describe "build/5 - edge cases" do
    test "empty session produces valid XML with no clipitems" do
      session = %{
        speech_markers: [],
        track_markers: [],
        started_at: nil,
        name: "Empty",
        source: :free,
        album: nil,
        playlist: nil
      }

      xml = XmemlExport.build(session, "", @timebase, @ntsc, @fixed_uuid)
      doc = parse_xml(xml)
      clips = xpath(doc, "/xmeml/sequence/media/video/track/clipitem")
      assert clips == []
    end

    test "xml-special characters in transcription are escaped" do
      session = %{
        speech_markers: [%SpeechMarker{start_ms: 1000, end_ms: 2000, text: ~s(A & B <tag> "quote")}],
        track_markers: [],
        started_at: ~U[2024-01-01 00:00:00Z],
        name: "Test",
        source: :free,
        album: nil,
        playlist: nil
      }

      xml = XmemlExport.build(session, "", @timebase, @ntsc, @fixed_uuid)
      assert xml =~ "&amp;"
      assert xml =~ "&lt;"
      assert xml =~ "&quot;"
      doc = parse_xml(xml)
      [comment] = xpath(doc, "/xmeml/sequence/media/video/track/clipitem/marker/comment")
      assert text_value(comment) == ~s(A & B <tag> "quote")
    end

    test "nil transcription produces empty marker comment" do
      session = %{
        speech_markers: [%SpeechMarker{start_ms: 1000, end_ms: 2000, text: nil}],
        track_markers: [],
        started_at: ~U[2024-01-01 00:00:00Z],
        name: "Test",
        source: :free,
        album: nil,
        playlist: nil
      }

      xml = XmemlExport.build(session, "", @timebase, @ntsc, @fixed_uuid)
      doc = parse_xml(xml)
      [comment] = xpath(doc, "/xmeml/sequence/media/video/track/clipitem/marker/comment")
      assert text_value(comment) == ""
    end

    test "blank media path produces recording.mp4 filename" do
      session = %{
        speech_markers: [%SpeechMarker{start_ms: 1000, end_ms: 2000, text: "hi"}],
        track_markers: [],
        started_at: ~U[2024-01-01 00:00:00Z],
        name: "Test",
        source: :free,
        album: nil,
        playlist: nil
      }

      xml = XmemlExport.build(session, "", @timebase, @ntsc, @fixed_uuid)
      assert xml =~ "recording.mp4"
    end
  end
end
