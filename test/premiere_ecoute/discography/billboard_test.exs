defmodule PremiereEcoute.Discography.BillboardTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Billboard

  describe "generate_billboard/1" do
    @tag :wip
    test "?" do
      urls = [
        "https://open.spotify.com/playlist/28Anwq5yS87ujCDWdFFr4b"
        # "https://open.spotify.com/playlist/0E6zyo5Q6UE0IzfkdbgENN",
        # "https://open.spotify.com/playlist/1mRj3UmaO5IE3rx8DKxThG",
        # "https://open.spotify.com/playlist/2gJc2T7Tm9TgPqRFrgfCJL"
      ]

      {:ok, %{playlists: playlists, tracks: tracks}} = Billboard.generate_billboard(urls)

      assert Enum.take(tracks, 2) == nil
    end
  end

  describe "extract_playlists/1" do
    test "extracts Spotify playlist IDs from URLs" do
      urls = [
        "https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd",
        "https://open.spotify.com/playlist/1a2b3c4d5e6f7g8h9i0j1k2l"
      ]

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"},
               {:deezer, "1234567890"}
             ]
    end

    test "handles empty list" do
      result = Billboard.extract_playlists([])
      assert result == []
    end

    test "handles list with only invalid URLs" do
      urls = [
        "https://invalid.url.com/playlist/123",
        "not a url",
        "https://youtube.com/playlist?list=abc123"
      ]

      result = Billboard.extract_playlists(urls)
      assert result == []
    end

    test "handles different Deezer language paths" do
      urls = [
        "https://www.deezer.com/en/playlist/1234567890",
        "https://www.deezer.com/fr/playlist/1111111111",
        "https://www.deezer.com/de/playlist/2222222222",
        "https://www.deezer.com/es/playlist/3333333333"
      ]

      result = Billboard.extract_playlists(urls)

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

      result = Billboard.extract_playlists(urls)

      # Only the valid Spotify URL should be extracted
      assert result == [
               {:spotify, "37i9dQZF1DX0XUsuxWHRQd"}
             ]
    end
  end

  describe "clean_value/1" do
    test "removes parenthetical content" do
      assert Billboard.clean_value("Song Name (Feat. Artist)") == "song name"
      assert Billboard.clean_value("Album Title (Deluxe Edition)") == "album title"
      assert Billboard.clean_value("Track (Live Version) Extra Text") == "track"
    end

    test "removes bracketed content" do
      assert Billboard.clean_value("Song [Explicit]") == "song"
      assert Billboard.clean_value("Album [Remastered]") == "album"
      assert Billboard.clean_value("Track [Radio Edit] More Text") == "track"
    end

    test "removes dash suffixes" do
      assert Billboard.clean_value("Song Name - Extended Mix") == "song name"
      assert Billboard.clean_value("Album Title - Special Edition") == "album title"
    end

    test "converts to lowercase" do
      assert Billboard.clean_value("UPPERCASE SONG") == "uppercase song"
      assert Billboard.clean_value("MiXeD CaSe") == "mixed case"
    end

    test "normalizes Unicode and removes diacritical marks" do
      assert Billboard.clean_value("Café") == "cafe"
      assert Billboard.clean_value("naïve") == "naive"
      assert Billboard.clean_value("résumé") == "resume"
      assert Billboard.clean_value("piñata") == "pinata"
    end

    test "removes punctuation marks" do
      assert Billboard.clean_value("Song!") == "song"
      assert Billboard.clean_value("?Question?") == "question"
      assert Billboard.clean_value("Song!!!") == "song"
      assert Billboard.clean_value("???Question???") == "question"
      assert Billboard.clean_value("Song with! exclamation") == "song with exclamation"
      assert Billboard.clean_value("Song with? question") == "song with question"
    end

    test "removes various special characters" do
      assert Billboard.clean_value("Song's") == "songs"
      assert Billboard.clean_value("Song*") == "song"
      assert Billboard.clean_value("Song,") == "song"
      assert Billboard.clean_value("Song.") == "song"
      assert Billboard.clean_value("Song'") == "song"
      assert Billboard.clean_value("Song:") == "song"
      assert Billboard.clean_value("Song_") == "song"
      assert Billboard.clean_value("Song/") == "song"
      assert Billboard.clean_value("Song-") == "song"
      assert Billboard.clean_value("¿Song¡") == "song"
    end

    test "handles special character replacements" do
      assert Billboard.clean_value("cœur") == "coeur"
      assert Billboard.clean_value("ca$h") == "cash"
      assert Billboard.clean_value("Bjørk") == "bjork"
    end

    test "trims whitespace" do
      assert Billboard.clean_value("  Song  ") == "song"
      assert Billboard.clean_value("\tSong\n") == "song"
    end

    test "handles complex combinations" do
      assert Billboard.clean_value("Café's Song! (Feat. Björk) - Extended Mix [Explicit]") == "cafes song"
      assert Billboard.clean_value("???What's Up??? (Radio Edit) - Remastered") == "whats up"
      assert Billboard.clean_value("  Naïve Café $ong [Live]  ") == "naive cafe song"
    end

    test "handles empty and whitespace-only strings" do
      assert Billboard.clean_value("") == ""
      assert Billboard.clean_value("   ") == ""
      assert Billboard.clean_value("\t\n") == ""
    end

    test "handles strings with only punctuation" do
      assert Billboard.clean_value("!!!") == ""
      assert Billboard.clean_value("???") == ""
      assert Billboard.clean_value("¿¡") == ""
    end
  end
end
