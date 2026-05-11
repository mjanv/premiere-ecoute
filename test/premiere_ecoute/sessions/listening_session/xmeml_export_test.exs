defmodule PremiereEcoute.Sessions.ListeningSession.XmemlExportTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Sessions.ListeningSession.SpeechMarker
  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker
  alias PremiereEcoute.Sessions.ListeningSession.XmemlExport
  alias PremiereEcouteCore.Xml

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
      assert {:xmlElement, :xmeml, _, _, _, _, _, _, _, _, _, _} = Xml.parse(xml)
    end

    test "xmeml version is 4", %{xml: xml} do
      doc = Xml.parse(xml)
      [el] = Xml.xpath(doc, "/xmeml")
      assert Xml.attr(el, :version) == "4"
    end

    test "sequence uuid matches reference", %{xml: xml, ref: ref} do
      doc = Xml.parse(xml)
      ref_doc = Xml.parse(ref)

      assert Xml.text(Xml.xpath(doc, "/xmeml/sequence/uuid")) ==
               Xml.text(Xml.xpath(ref_doc, "/xmeml/sequence/uuid"))
    end

    test "sequence duration matches reference", %{xml: xml, ref: ref} do
      doc = Xml.parse(xml)
      ref_doc = Xml.parse(ref)

      assert Xml.text(Xml.xpath(doc, "/xmeml/sequence/duration")) ==
               Xml.text(Xml.xpath(ref_doc, "/xmeml/sequence/duration"))
    end

    test "has exactly 1 video track (no chapter track)", %{xml: xml} do
      doc = Xml.parse(xml)
      tracks = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(tracks) == 1
    end

    test "speech track has 3 clipitems", %{xml: xml} do
      doc = Xml.parse(xml)
      clips = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem")
      assert length(clips) == 3
    end

    test "clipitem ids match reference", %{xml: xml, ref: ref} do
      doc = Xml.parse(xml)
      ref_doc = Xml.parse(ref)

      ids = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem") |> Enum.map(&Xml.attr(&1, :id))
      ref_ids = Xml.xpath(ref_doc, "/xmeml/sequence/media/video/track/clipitem") |> Enum.map(&Xml.attr(&1, :id))

      assert ids == ref_ids
    end

    test "first clipitem start/end/in/out match reference", %{xml: xml, ref: ref} do
      doc = Xml.parse(xml)
      ref_doc = Xml.parse(ref)

      for field <- ~w(start end in out) do
        path = "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/#{field}"
        assert Xml.text(Xml.xpath(doc, path)) == Xml.text(Xml.xpath(ref_doc, path))
      end
    end

    test "clip names are Clip 001, Clip 002, Clip 003", %{xml: xml} do
      doc = Xml.parse(xml)
      names = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem/name") |> Xml.text()
      assert names == ["Clip 001", "Clip 002", "Clip 003"]
    end

    test "marker comments contain transcription text", %{xml: xml} do
      doc = Xml.parse(xml)
      comments = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem/marker/comment") |> Xml.text()
      assert Enum.at(comments, 0) =~ "welcome to the stream"
      assert Enum.at(comments, 1) =~ "let's go"
      assert Enum.at(comments, 2) == "Background music starts"
    end

    test "first clipitem declares file-1 fully, others reference it", %{xml: xml} do
      doc = Xml.parse(xml)

      # clipitem-1 should have a full file element with pathurl
      [pathurl] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/file/pathurl")
      assert Xml.text(pathurl) =~ "Sample%20Media%20Clip%208.mp4"

      # clipitem-2 should have a self-referencing file element (no pathurl child)
      pathrefs2 = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-2']/file/pathurl")
      assert pathrefs2 == []
    end

    test "has 2 audio tracks", %{xml: xml} do
      doc = Xml.parse(xml)
      tracks = Xml.xpath(doc, "/xmeml/sequence/media/audio/track")
      assert length(tracks) == 2
    end

    test "audio tracks have 3 clipitems each", %{xml: xml} do
      doc = Xml.parse(xml)
      tracks = Xml.xpath(doc, "/xmeml/sequence/media/audio/track")

      for track <- tracks do
        clips = Xml.xpath(track, "clipitem")
        assert length(clips) == 3
      end
    end

    test "pathurl uses file://localhost/ format for Windows paths", %{xml: xml} do
      doc = Xml.parse(xml)
      [pathurl] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/file/pathurl")
      assert Xml.text(pathurl) =~ "file://localhost/"
    end

    test "pathurl encodes colon in drive letter as %3a", %{xml: xml} do
      doc = Xml.parse(xml)
      [pathurl] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/file/pathurl")
      assert Xml.text(pathurl) =~ "C%3a"
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
      assert {:xmlElement, :xmeml, _, _, _, _, _, _, _, _, _, _} = Xml.parse(xml)
    end

    test "has 2 video tracks", %{xml: xml} do
      doc = Xml.parse(xml)
      tracks = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(tracks) == 2
    end

    test "speech track (V1) has 3 clipitems", %{xml: xml} do
      doc = Xml.parse(xml)
      [speech_track | _] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(Xml.xpath(speech_track, "clipitem")) == 3
    end

    test "chapter track (V2) has 2 clipitems", %{xml: xml} do
      doc = Xml.parse(xml)
      [_, chapter_track] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      assert length(Xml.xpath(chapter_track, "clipitem")) == 2
    end

    test "chapter clipitem names match track names", %{xml: xml} do
      doc = Xml.parse(xml)
      [_, chapter_track] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      names = Xml.xpath(chapter_track, "clipitem/name") |> Xml.text()
      assert names == ["Chapter 01 - Introduction", "Chapter 02 - Conclusion"]
    end

    test "chapter clipitems have independent file declarations (no cross-track idref)", %{xml: xml} do
      doc = Xml.parse(xml)
      [_, chapter_track] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      clips = Xml.xpath(chapter_track, "clipitem")

      for clip <- clips do
        [file] = Xml.xpath(clip, "file")
        file_id = Xml.attr(file, :id)
        assert file_id != "file-1", "Chapter track must not reuse file-1 from speech track"
        pathrls = Xml.xpath(file, "pathurl")
        assert length(pathrls) == 1, "Chapter clipitem must have full file declaration with pathurl"
      end
    end

    test "chapter track clipitem start frames match reference", %{xml: xml, ref: ref} do
      doc = Xml.parse(xml)
      ref_doc = Xml.parse(ref)

      for id <- ["clipitem-10", "clipitem-11"] do
        path = "/xmeml/sequence/media/video/track/clipitem[@id='#{id}']/start"
        assert Xml.text(Xml.xpath(doc, path)) == Xml.text(Xml.xpath(ref_doc, path))
      end
    end

    test "chapter labels are Lavender", %{xml: xml} do
      doc = Xml.parse(xml)
      [_, chapter_track] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      labels = Xml.xpath(chapter_track, "clipitem/labels/label2") |> Xml.text()
      assert Enum.all?(labels, &(&1 == "Lavender"))
    end

    test "speech labels are Iris", %{xml: xml} do
      doc = Xml.parse(xml)
      [speech_track | _] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      labels = Xml.xpath(speech_track, "clipitem/labels/label2") |> Xml.text()
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
      doc = Xml.parse(xml)
      clips = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem")
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
      doc = Xml.parse(xml)
      [comment] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem/marker/comment")
      assert Xml.text(comment) == ~s(A & B <tag> "quote")
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
      doc = Xml.parse(xml)
      [comment] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem/marker/comment")
      assert Xml.text(comment) == ""
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

  # ---------------------------------------------------------------------------
  # Tests: time bias
  # ---------------------------------------------------------------------------

  describe "build/7 - time bias" do
    test "shifts speech clipitem positions by bias_ms" do
      session = speech_only_session()
      # bias 4000ms @ 25fps = 100 frames; first marker original 12_840ms = 321f → 321 + 100 = 421
      xml = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000, 4000)
      doc = Xml.parse(xml)

      [start_el] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/start")
      [end_el] = Xml.xpath(doc, "/xmeml/sequence/media/video/track/clipitem[@id='clipitem-1']/end")

      assert Xml.text(start_el) == "421"
      # original end 14_440ms = 361f → 461
      assert Xml.text(end_el) == "461"
    end

    test "shifts chapter clipitem positions by bias_ms" do
      session = speech_and_chapters_session()
      # First chapter original 12_840ms = 321f, with 4000ms bias → 421
      xml = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000, 4000)
      doc = Xml.parse(xml)

      [_, chapter_track] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      [first_chapter | _] = Xml.xpath(chapter_track, "clipitem")
      [start_el] = Xml.xpath(first_chapter, "start")

      assert Xml.text(start_el) == "421"
    end

    test "shifts audio clipitem positions by bias_ms" do
      session = speech_only_session()
      xml = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000, 4000)
      doc = Xml.parse(xml)

      [first_audio_clip | _] = Xml.xpath(doc, "/xmeml/sequence/media/audio/track[1]/clipitem")
      [start_el] = Xml.xpath(first_audio_clip, "start")

      assert Xml.text(start_el) == "421"
    end

    test "extends sequence duration by bias_ms" do
      session = speech_only_session()
      # Last marker end 21_360ms = 534f, +4000ms (100f) = 634
      xml = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000, 4000)
      doc = Xml.parse(xml)

      [duration_el] = Xml.xpath(doc, "/xmeml/sequence/duration")
      assert Xml.text(duration_el) == "634"
    end

    test "default bias is 0 (positions match unbiased build)" do
      session = speech_only_session()
      xml_default = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000)
      xml_zero = XmemlExport.build(session, @media_path, @timebase, @ntsc, @fixed_uuid, 1000, 0)
      assert xml_default == xml_zero
    end
  end
end
