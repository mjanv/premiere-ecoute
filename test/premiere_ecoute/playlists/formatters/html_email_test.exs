defmodule PremiereEcoute.Playlists.Formatters.HtmlEmailTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Formatters.Formatter
  alias PremiereEcoute.Playlists.Formatters.HtmlEmail

  defp playlist(attrs \\ %{}) do
    struct(
      %LibraryPlaylist{
        title: "My Playlist",
        description: "A great playlist",
        url: "https://open.spotify.com/playlist/abc",
        cover_url: "https://example.com/cover.jpg",
        track_count: 12,
        provider: :spotify
      },
      attrs
    )
  end

  defp track(attrs \\ %{}) do
    Map.merge(
      %{
        track_id: "track_abc",
        name: "Some Track",
        artist: "Some Artist",
        duration_ms: 210_000,
        release_date: ~D[2024-01-15]
      },
      attrs
    )
  end

  describe "format/2 — playlist header" do
    test "includes the playlist title" do
      {:ok, html} = Formatter.format(%HtmlEmail{}, playlist())

      assert html =~ "My Playlist"
    end

    test "includes cover image when cover_url is present" do
      {:ok, html} = Formatter.format(%HtmlEmail{}, playlist())

      assert html =~ ~s(src="https://example.com/cover.jpg")
    end

    test "omits cover image when cover_url is nil" do
      {:ok, html} = Formatter.format(%HtmlEmail{}, playlist(%{cover_url: nil}))

      refute html =~ "<img"
    end

    test "includes track count from playlist" do
      {:ok, html} = Formatter.format(%HtmlEmail{}, playlist())

      assert html =~ "12"
    end

    test "prefers track_count from formatter over playlist" do
      {:ok, html} = Formatter.format(%HtmlEmail{track_count: 5}, playlist())

      assert html =~ "5 tracks"
      refute html =~ "12 tracks"
    end

    test "prefers cover_url from formatter over playlist" do
      {:ok, html} = Formatter.format(%HtmlEmail{cover_url: "https://example.com/live.jpg"}, playlist())

      assert html =~ "https://example.com/live.jpg"
      refute html =~ "https://example.com/cover.jpg"
    end
  end

  describe "format/2 — track list" do
    test "lists track name and artist" do
      {:ok, html} = Formatter.format(%HtmlEmail{tracks: [track()]}, playlist())

      assert html =~ "Some Track"
      assert html =~ "Some Artist"
    end

    test "includes a link to the Spotify track" do
      {:ok, html} = Formatter.format(%HtmlEmail{tracks: [track(%{track_id: "abc123"})]}, playlist())

      assert html =~ "https://open.spotify.com/track/abc123"
    end

    test "lists multiple tracks" do
      tracks = [track(%{name: "Track One"}), track(%{name: "Track Two"})]
      {:ok, html} = Formatter.format(%HtmlEmail{tracks: tracks}, playlist())

      assert html =~ "Track One"
      assert html =~ "Track Two"
    end

    test "renders no track rows when tracks list is empty" do
      {:ok, html} = Formatter.format(%HtmlEmail{tracks: []}, playlist())

      refute html =~ "open.spotify.com/track"
    end
  end
end
