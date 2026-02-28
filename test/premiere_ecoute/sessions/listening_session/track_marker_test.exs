defmodule PremiereEcoute.Sessions.ListeningSession.TrackMarkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track, as: AlbumTrack
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.TrackMarker

  describe "format_youtube_chapters/2" do
    test "returns empty string when no track markers exist" do
      session = %ListeningSession{track_markers: []}

      assert TrackMarker.format_youtube_chapters(session, 0) == ""
    end

    test "formats multiple track markers for album session with zero bias" do
      session_start = ~U[2025-01-15 10:00:00Z]
      track1_start = ~U[2025-01-15 10:00:30Z]
      track2_start = ~U[2025-01-15 10:04:15Z]
      track3_start = ~U[2025-01-15 10:08:45Z]

      album = %Album{
        tracks: [
          %AlbumTrack{id: 1, name: "Opening Song"},
          %AlbumTrack{id: 2, name: "Second Song"},
          %AlbumTrack{id: 3, name: "Third Song"}
        ]
      }

      session = %ListeningSession{
        source: :album,
        album: album,
        started_at: session_start,
        ended_at: nil,
        track_markers: [
          %TrackMarker{id: 1, track_id: 1, track_number: 1, started_at: track1_start},
          %TrackMarker{id: 2, track_id: 2, track_number: 2, started_at: track2_start},
          %TrackMarker{id: 3, track_id: 3, track_number: 3, started_at: track3_start}
        ]
      }

      result = TrackMarker.format_youtube_chapters(session, 0)

      assert result == """
             0:30 Opening Song
             4:15 Second Song
             8:45 Third Song\
             """
    end

    test "formats track markers for playlist session with zero bias" do
      session_start = ~U[2025-01-15 10:00:00Z]
      track_start = ~U[2025-01-15 10:01:00Z]

      playlist = %Playlist{
        tracks: [
          %PlaylistTrack{id: 10, name: "Playlist Track One"}
        ]
      }

      session = %ListeningSession{
        source: :playlist,
        playlist: playlist,
        started_at: session_start,
        ended_at: nil,
        track_markers: [
          %TrackMarker{
            id: 1,
            track_id: 10,
            track_number: 1,
            started_at: track_start
          }
        ]
      }

      result = TrackMarker.format_youtube_chapters(session, 0)

      assert result == "1:00 Playlist Track One"
    end

    test "applies positive time bias to all chapters" do
      session_start = ~U[2025-01-15 10:00:00Z]
      track1_start = ~U[2025-01-15 10:00:30Z]
      track2_start = ~U[2025-01-15 10:03:00Z]

      album = %Album{
        tracks: [
          %AlbumTrack{id: 1, name: "Track One"},
          %AlbumTrack{id: 2, name: "Track Two"}
        ]
      }

      session = %ListeningSession{
        source: :album,
        album: album,
        started_at: session_start,
        ended_at: nil,
        track_markers: [
          %TrackMarker{id: 1, track_id: 1, track_number: 1, started_at: track1_start},
          %TrackMarker{id: 2, track_id: 2, track_number: 2, started_at: track2_start}
        ]
      }

      # Apply 60 second (1:00) bias
      result = TrackMarker.format_youtube_chapters(session, 60)

      assert result == """
             0:00 Introduction
             1:30 Track One
             4:00 Track Two\
             """
    end

    test "adds Introduction chapter at 0:00 when bias is greater than zero" do
      session_start = ~U[2025-01-15 10:00:00Z]
      track_start = ~U[2025-01-15 10:00:30Z]

      album = %Album{
        tracks: [%AlbumTrack{id: 1, name: "First Track"}]
      }

      session = %ListeningSession{
        source: :album,
        album: album,
        started_at: session_start,
        ended_at: nil,
        track_markers: [
          %TrackMarker{id: 1, track_id: 1, track_number: 1, started_at: track_start}
        ]
      }

      result = TrackMarker.format_youtube_chapters(session, 120)

      assert result == """
             0:00 Introduction
             2:30 First Track\
             """
    end

    test "adds Conclusion chapter when session has ended" do
      session_start = ~U[2025-01-15 10:00:00Z]
      track_start = ~U[2025-01-15 10:00:30Z]
      session_end = ~U[2025-01-15 10:10:00Z]

      album = %Album{
        tracks: [%AlbumTrack{id: 1, name: "Only Track"}]
      }

      session = %ListeningSession{
        source: :album,
        album: album,
        started_at: session_start,
        ended_at: session_end,
        track_markers: [
          %TrackMarker{id: 1, track_id: 1, track_number: 1, started_at: track_start}
        ]
      }

      result = TrackMarker.format_youtube_chapters(session, 0)

      assert result == """
             0:30 Only Track
             10:00 Conclusion\
             """
    end

    test "formats timestamps correctly for durations over 1 hour" do
      session_start = ~U[2025-01-15 10:00:00Z]
      track_start = ~U[2025-01-15 11:30:45Z]

      album = %Album{
        tracks: [%AlbumTrack{id: 1, name: "Long Track"}]
      }

      session = %ListeningSession{
        source: :album,
        album: album,
        started_at: session_start,
        ended_at: nil,
        track_markers: [
          %TrackMarker{id: 1, track_id: 1, track_number: 1, started_at: track_start}
        ]
      }

      result = TrackMarker.format_youtube_chapters(session, 0)

      assert result == "1:30:45 Long Track"
    end

    test "complete example with Introduction, multiple tracks, and Conclusion" do
      session_start = ~U[2025-01-15 10:00:00Z]
      session_end = ~U[2025-01-15 10:15:00Z]

      album = %Album{
        tracks: [
          %AlbumTrack{id: 1, name: "Opener"},
          %AlbumTrack{id: 2, name: "Main Event"},
          %AlbumTrack{id: 3, name: "Finale"}
        ]
      }

      session = %ListeningSession{
        source: :album,
        album: album,
        started_at: session_start,
        ended_at: session_end,
        track_markers: [
          %TrackMarker{
            id: 1,
            track_id: 1,
            track_number: 1,
            started_at: ~U[2025-01-15 10:00:30Z]
          },
          %TrackMarker{
            id: 2,
            track_id: 2,
            track_number: 2,
            started_at: ~U[2025-01-15 10:05:00Z]
          },
          %TrackMarker{
            id: 3,
            track_id: 3,
            track_number: 3,
            started_at: ~U[2025-01-15 10:10:30Z]
          }
        ]
      }

      # 2 minute bias
      result = TrackMarker.format_youtube_chapters(session, 120)

      assert result == """
             0:00 Introduction
             2:30 Opener
             7:00 Main Event
             12:30 Finale
             17:00 Conclusion\
             """
    end
  end
end
