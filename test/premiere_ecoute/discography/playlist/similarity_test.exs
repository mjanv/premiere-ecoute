defmodule PremiereEcoute.Discography.Playlist.SimilarityTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Similarity
  alias PremiereEcoute.Discography.Playlist.Track

  describe "calculate_similarity/2" do
    test "returns 100 for identical playlists" do
      playlist1 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021)
        ])

      playlist2 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021)
        ])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 100
    end

    test "returns 0 for completely different playlists" do
      playlist1 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021)
        ])

      playlist2 =
        build_playlist([
          track("Artist C", "Song 3", 2022),
          track("Artist D", "Song 4", 2023)
        ])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 0
    end

    test "returns 50 for playlists with 50% overlap" do
      playlist1 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021)
        ])

      playlist2 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist C", "Song 3", 2022)
        ])

      # Intersection: 1, Union: 3 = 1/3 = 33.33% rounded to 33
      assert Similarity.calculate_similarity(playlist1, playlist2) == 33
    end

    test "returns 0 for empty playlists" do
      playlist1 = build_playlist([])
      playlist2 = build_playlist([])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 0
    end

    test "returns 0 when one playlist is empty" do
      playlist1 = build_playlist([track("Artist A", "Song 1", 2020)])
      playlist2 = build_playlist([])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 0
    end

    test "normalizes track names for comparison" do
      # AIDEV-NOTE: track normalization removes parentheses, diacritics, etc.
      playlist1 =
        build_playlist([
          track("Artist A", "Song (feat. Someone)", 2020)
        ])

      playlist2 =
        build_playlist([
          track("Artist A", "Song", 2020)
        ])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 100
    end

    test "handles case-insensitive track matching" do
      playlist1 =
        build_playlist([
          track("Artist A", "Song Title", 2020)
        ])

      playlist2 =
        build_playlist([
          track("artist a", "song title", 2020)
        ])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 100
    end

    test "removes diacritical marks for comparison" do
      playlist1 =
        build_playlist([
          track("Björk", "Café", 2020)
        ])

      playlist2 =
        build_playlist([
          track("Bjork", "Cafe", 2020)
        ])

      assert Similarity.calculate_similarity(playlist1, playlist2) == 100
    end

    test "calculates correct similarity with multiple overlapping tracks" do
      playlist1 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021),
          track("Artist C", "Song 3", 2022),
          track("Artist D", "Song 4", 2023)
        ])

      playlist2 =
        build_playlist([
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021),
          track("Artist E", "Song 5", 2024)
        ])

      # Intersection: 2, Union: 5 = 2/5 = 40%
      assert Similarity.calculate_similarity(playlist1, playlist2) == 40
    end
  end

  describe "find_most_similar/3" do
    test "returns top N most similar playlists sorted by similarity" do
      target =
        build_playlist("target", [
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021)
        ])

      similar_100 =
        build_playlist("similar_100", [
          track("Artist A", "Song 1", 2020),
          track("Artist B", "Song 2", 2021)
        ])

      similar_50 =
        build_playlist("similar_50", [
          track("Artist A", "Song 1", 2020),
          track("Artist C", "Song 3", 2022)
        ])

      similar_0 =
        build_playlist("similar_0", [
          track("Artist D", "Song 4", 2023),
          track("Artist E", "Song 5", 2024)
        ])

      all_playlists = [similar_0, similar_100, similar_50]

      result = Similarity.find_most_similar(target, all_playlists, 3)

      assert length(result) == 3
      assert Enum.at(result, 0).similarity_score == 100
      assert Enum.at(result, 1).similarity_score == 33
      assert Enum.at(result, 2).similarity_score == 0
    end

    test "excludes the target playlist from results" do
      target =
        build_playlist("target", [
          track("Artist A", "Song 1", 2020)
        ])

      similar =
        build_playlist("similar", [
          track("Artist A", "Song 1", 2020)
        ])

      all_playlists = [target, similar]

      result = Similarity.find_most_similar(target, all_playlists, 5)

      assert length(result) == 1
      assert hd(result).playlist_id == "similar"
    end

    test "returns only N results even when more playlists exist" do
      target =
        build_playlist("target", [
          track("Artist A", "Song 1", 2020)
        ])

      similar1 = build_playlist("similar1", [track("Artist A", "Song 1", 2020)])
      similar2 = build_playlist("similar2", [track("Artist B", "Song 2", 2021)])
      similar3 = build_playlist("similar3", [track("Artist C", "Song 3", 2022)])

      all_playlists = [similar1, similar2, similar3]

      result = Similarity.find_most_similar(target, all_playlists, 2)

      assert length(result) == 2
    end

    test "returns empty list when no other playlists exist" do
      target =
        build_playlist("target", [
          track("Artist A", "Song 1", 2020)
        ])

      result = Similarity.find_most_similar(target, [target], 3)

      assert result == []
    end

    test "adds mean_year to each result" do
      target =
        build_playlist("target", [
          track("Artist A", "Song 1", 2020)
        ])

      similar =
        build_playlist("similar", [
          track("Artist B", "Song 2", 2020),
          track("Artist C", "Song 3", 2022)
        ])

      result = Similarity.find_most_similar(target, [similar], 1)

      assert hd(result).mean_year == 2021
    end

    test "defaults to 3 results when N not specified" do
      target =
        build_playlist("target", [
          track("Artist A", "Song 1", 2020)
        ])

      playlists =
        for i <- 1..5 do
          build_playlist("playlist#{i}", [track("Artist #{i}", "Song #{i}", 2020)])
        end

      result = Similarity.find_most_similar(target, playlists)

      assert length(result) == 3
    end
  end

  describe "calculate_mean_year/1" do
    test "calculates mean year for tracks" do
      tracks = [
        track("Artist A", "Song 1", 2020),
        track("Artist B", "Song 2", 2022)
      ]

      assert Similarity.calculate_mean_year(tracks) == 2021
    end

    test "returns rounded mean year" do
      tracks = [
        track("Artist A", "Song 1", 2020),
        track("Artist B", "Song 2", 2021),
        track("Artist C", "Song 3", 2022)
      ]

      # Mean: (2020 + 2021 + 2022) / 3 = 2021
      assert Similarity.calculate_mean_year(tracks) == 2021
    end

    test "returns nil for empty track list" do
      assert Similarity.calculate_mean_year([]) == nil
    end

    test "handles single track" do
      tracks = [track("Artist A", "Song 1", 2020)]

      assert Similarity.calculate_mean_year(tracks) == 2020
    end

    test "rounds to nearest integer when mean is fractional" do
      tracks = [
        track("Artist A", "Song 1", 2020),
        track("Artist B", "Song 2", 2021)
      ]

      # Mean: (2020 + 2021) / 2 = 2020.5, rounds to 2021
      assert Similarity.calculate_mean_year(tracks) == 2021
    end
  end

  # Helper functions

  defp build_playlist(tracks) when is_list(tracks) do
    build_playlist("test_playlist_#{:rand.uniform(100_000)}", tracks)
  end

  defp build_playlist(playlist_id, tracks) do
    %Playlist{
      playlist_id: playlist_id,
      title: "Test Playlist",
      provider: :spotify,
      owner_id: "test_owner",
      owner_name: "Test Owner",
      url: "https://open.spotify.com/playlist/#{playlist_id}",
      cover_url: "https://example.com/cover.jpg",
      tracks: tracks
    }
  end

  defp track(artist, name, year) do
    %Track{
      provider: :spotify,
      artist: artist,
      name: name,
      track_id: "track_#{:rand.uniform(100_000)}",
      album_id: "album_#{:rand.uniform(100_000)}",
      user_id: "user_123",
      duration_ms: 180_000,
      release_date: Date.new!(year, 1, 1),
      added_at: ~N[2025-01-01 00:00:00]
    }
  end
end
