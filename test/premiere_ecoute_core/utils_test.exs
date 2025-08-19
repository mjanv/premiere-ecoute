defmodule PremiereEcouteCore.UtilsTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.Utils

  describe "sanitize_track/1" do
    test "removes parenthetical content" do
      assert Utils.sanitize_track("Song Name (Feat. Artist)") == "song name"
      assert Utils.sanitize_track("Album Title (Deluxe Edition)") == "album title"
      assert Utils.sanitize_track("Track (Live Version) Extra Text") == "track"
    end

    test "removes bracketed content" do
      assert Utils.sanitize_track("Song [Explicit]") == "song"
      assert Utils.sanitize_track("Album [Remastered]") == "album"
      assert Utils.sanitize_track("Track [Radio Edit] More Text") == "track"
    end

    test "removes dash suffixes" do
      assert Utils.sanitize_track("Song Name - Extended Mix") == "song name"
      assert Utils.sanitize_track("Album Title - Special Edition") == "album title"
    end

    test "converts to lowercase" do
      assert Utils.sanitize_track("UPPERCASE SONG") == "uppercase song"
      assert Utils.sanitize_track("MiXeD CaSe") == "mixed case"
    end

    test "normalizes Unicode and removes diacritical marks" do
      assert Utils.sanitize_track("Café") == "cafe"
      assert Utils.sanitize_track("naïve") == "naive"
      assert Utils.sanitize_track("résumé") == "resume"
      assert Utils.sanitize_track("piñata") == "pinata"
    end

    test "removes punctuation marks" do
      assert Utils.sanitize_track("Song!") == "song"
      assert Utils.sanitize_track("?Question?") == "question"
      assert Utils.sanitize_track("Song!!!") == "song"
      assert Utils.sanitize_track("???Question???") == "question"
      assert Utils.sanitize_track("Song with! exclamation") == "song with exclamation"
      assert Utils.sanitize_track("Song with? question") == "song with question"
    end

    test "removes various special characters" do
      assert Utils.sanitize_track("Song's") == "songs"
      assert Utils.sanitize_track("Song*") == "song"
      assert Utils.sanitize_track("Song,") == "song"
      assert Utils.sanitize_track("Song.") == "song"
      assert Utils.sanitize_track("Song'") == "song"
      assert Utils.sanitize_track("Song:") == "song"
      assert Utils.sanitize_track("Song_") == "song"
      assert Utils.sanitize_track("Song/") == "song"
      assert Utils.sanitize_track("Song-") == "song"
      assert Utils.sanitize_track("¿Song¡") == "song"
    end

    test "handles special character replacements" do
      assert Utils.sanitize_track("cœur") == "coeur"
      assert Utils.sanitize_track("ca$h") == "cash"
      assert Utils.sanitize_track("Bjørk") == "bjork"
    end

    test "trims whitespace" do
      assert Utils.sanitize_track("  Song  ") == "song"
      assert Utils.sanitize_track("\tSong\n") == "song"
    end

    test "handles complex combinations" do
      assert Utils.sanitize_track("Café's Song! (Feat. Björk) - Extended Mix [Explicit]") == "cafes song"
      assert Utils.sanitize_track("???What's Up??? (Radio Edit) - Remastered") == "whats up"
      assert Utils.sanitize_track("  Naïve Café $ong [Live]  ") == "naive cafe song"
    end

    test "handles empty and whitespace-only strings" do
      assert Utils.sanitize_track("") == ""
      assert Utils.sanitize_track("   ") == ""
      assert Utils.sanitize_track("\t\n") == ""
    end

    test "handles strings with only punctuation" do
      assert Utils.sanitize_track("!!!") == ""
      assert Utils.sanitize_track("???") == ""
      assert Utils.sanitize_track("¿¡") == ""
    end
  end
end
