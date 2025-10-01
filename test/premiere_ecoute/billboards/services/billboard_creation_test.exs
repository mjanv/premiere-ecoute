defmodule PremiereEcoute.Billboards.Services.BillboardCreationTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Services.BillboardCreation
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  
  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi

  describe "generate_billboard/1" do
    test "generate a billboard from a list of playlist URLs" do
      
      playlist = playlist_fixture()
      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)
      
      urls = [
        "https://open.spotify.com/playlist/28Anwq5yS87ujCDWdFFr4b"
      ]

      {:ok, %{playlists: playlists, track: track, artist: artist, year: year, year_podium: year_podium}} = Billboards.generate_billboard(urls, [])
      
      
      assert [%{count: 1, year: 2025, rank: 1, tracks: [_], track_count: 1, max_count: 1}] = year
      assert [%{count: 1, year: 2025, rank: 1, tracks: [_], track_count: 1, max_count: 1}] = year_podium
      assert [%{count: 1, artist: "Unknown Artist", rank: 1, tracks: [_], track_count: 1}] = artist
      assert [%{count: 1, track: %Track{name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)"}, rank: 1, tracks: [_]}] = track
      assert [%Playlist{playlist_id: "2gW4sqiC2OXZLe9m0yDQX7"}] = playlists
    end
  end

  describe "extract_playlist_ids/1" do
    test "extracts Spotify playlist IDs from URLs" do
      urls = [
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
        "https://open.spotify.com/playlist/1a2b3c4d5e6f7g8h9i0j1k2l"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:spotify, "1a2b3c4d5e6f7g8h9i0j1k2l"}
             ]
    end

    test "extracts Deezer playlist IDs from URLs" do
      urls = [
        "https://www.deezer.com/en/playlist/1234567890",
        "https://www.deezer.com/fr/playlist/9876543210"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:deezer, "1234567890"},
               {:deezer, "9876543210"}
             ]
    end

    test "handles mixed Spotify and Deezer URLs" do
      urls = [
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
        "https://www.deezer.com/en/playlist/1234567890",
        "https://open.spotify.com/playlist/1a2b3c4d5e6f7g8h9i0j1k2l"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:deezer, "1234567890"},
               {:spotify, "1a2b3c4d5e6f7g8h9i0j1k2l"}
             ]
    end

    test "handles Spotify URLs with query parameters" do
      urls = [
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd?si=abc123def456",
        "https://open.spotify.com/playlist/1a2b3c4d5e6f7g8h9i0j1k2l?utm_source=copy-link"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:spotify, "1a2b3c4d5e6f7g8h9i0j1k2l"}
             ]
    end

    test "handles Deezer URLs with query parameters" do
      urls = [
        "https://www.deezer.com/en/playlist/1234567890?utm_source=deezer",
        "https://www.deezer.com/fr/playlist/9876543210?autoplay=true"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:deezer, "1234567890"},
               {:deezer, "9876543210"}
             ]
    end

    test "trims whitespace from URLs" do
      urls = [
        "  https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd  ",
        "\thttps://www.deezer.com/en/playlist/1234567890\n"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:deezer, "1234567890"}
             ]
    end

    test "filters out invalid URLs" do
      urls = [
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
        "https://invalid.url.com/playlist/123",
        "not a url at all",
        "https://www.deezer.com/en/playlist/1234567890",
        "https://youtube.com/playlist?list=abc123"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:deezer, "1234567890"}
             ]
    end

    test "removes duplicate playlists" do
      urls = [
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd?si=different-param",
        "https://www.deezer.com/en/playlist/1234567890",
        "https://www.deezer.com/fr/playlist/1234567890"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:deezer, "1234567890"}
             ]
    end

    test "handles empty list" do
      result = BillboardCreation.extract_playlist_ids([])
      assert result == []
    end

    test "handles list with only invalid URLs" do
      urls = [
        "https://invalid.url.com/playlist/123",
        "not a url",
        "https://youtube.com/playlist?list=abc123"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)
      assert result == []
    end

    test "handles different Deezer language paths" do
      urls = [
        "https://www.deezer.com/en/playlist/1234567890",
        "https://www.deezer.com/fr/playlist/1111111111",
        "https://www.deezer.com/de/playlist/2222222222",
        "https://www.deezer.com/es/playlist/3333333333"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      assert result == [
               {:deezer, "1234567890"},
               {:deezer, "1111111111"},
               {:deezer, "2222222222"},
               {:deezer, "3333333333"}
             ]
    end

    test "handles malformed but partially valid URLs" do
      urls = [
        # missing ID
        "https://open.spotify.com/playlist/",
        # missing ID
        "https://www.deezer.com/en/playlist/",
        # valid
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
        # missing language but ID present
        "https://www.deezer.com/playlist/1234567890"
      ]

      result = BillboardCreation.extract_playlist_ids(urls)

      # Only the valid Spotify URL should be extracted
      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"}
             ]
    end
  end
end
