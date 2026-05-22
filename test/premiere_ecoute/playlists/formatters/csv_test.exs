defmodule PremiereEcoute.Playlists.Formatters.CsvTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Formatters.Csv
  alias PremiereEcoute.Playlists.Formatters.Formatter

  defp playlist(attrs \\ %{}) do
    struct(
      %LibraryPlaylist{
        title: "My Playlist",
        url: "https://open.spotify.com/playlist/abc",
        track_count: 12,
        provider: :spotify
      },
      attrs
    )
  end

  describe "format/2" do
    test "produces a header row" do
      {:ok, csv} = Formatter.format(%Csv{}, playlist())

      assert String.starts_with?(csv, "title,track_count,url,provider")
    end

    test "produces a data row with playlist fields" do
      {:ok, csv} = Formatter.format(%Csv{}, playlist())
      [_header, row] = String.split(csv, "\n", parts: 2)

      assert row =~ "My Playlist"
      assert row =~ "12"
      assert row =~ "https://open.spotify.com/playlist/abc"
      assert row =~ "spotify"
    end
  end
end
