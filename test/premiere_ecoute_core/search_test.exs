defmodule PremiereEcouteCore.SearchTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcouteCore.Search

  @tracks [
    %Track{name: "Mr. Brightside", artist: "The Killers", provider: :spotify},
    %Track{name: "Smells Like Teen Spirit", artist: "Nirvana", provider: :spotify},
    %Track{name: "Lose Yourself", artist: "Eminem", provider: :deezer},
    %Track{name: "Blinding Lights", artist: "The Weeknd", provider: :spotify},
    %Track{name: "Shape of You", artist: "Ed Sheeran", provider: :deezer},
    %Track{name: "HUMBLE.", artist: "Kendrick Lamar", provider: :spotify},
    %Track{name: "Billie Jean", artist: "Michael Jackson", provider: :deezer},
    %Track{name: "Bohemian Rhapsody", artist: "Queen", provider: :spotify},
    %Track{name: "Rolling in the Deep", artist: "Adele", provider: :deezer},
    %Track{name: "Hotel California", artist: "Eagles", provider: :spotify}
  ]

  @submissions [
    %{url: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp", provider: :spotify, reviewed?: true},
    %{url: "https://open.spotify.com/track/7GhIk7Il098yCjg4BQjzvb", provider: :spotify, reviewed?: false},
    %{url: "https://www.deezer.com/track/3135556", provider: :deezer, reviewed?: true},
    %{url: "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b", provider: :spotify, reviewed?: false},
    %{url: "https://www.deezer.com/track/1109731", provider: :deezer, reviewed?: true},
    %{url: "https://open.spotify.com/track/6habFhsOp2NvshLv26DqMb", provider: :spotify, reviewed?: true},
    %{url: "https://www.deezer.com/track/916424", provider: :deezer, reviewed?: false},
    %{url: "https://open.spotify.com/track/2takcwOaAZWiXQijPHIx7B", provider: :spotify, reviewed?: true},
    %{url: "https://www.deezer.com/track/1109732", provider: :deezer, reviewed?: false},
    %{url: "https://open.spotify.com/track/1AhDOtG9vPSOmsWgNW0BEY", provider: :spotify, reviewed?: true}
  ]

  describe "filter/1" do
    test "does not apply with empty queries" do
      tracks = Search.filter(@tracks, "", [:name, :artist, :provider])

      assert tracks == @tracks
    end

    test "can search structs by string field" do
      tracks = Search.filter(@tracks, "Bohemian", [:name, :artist, :provider])

      assert tracks == [
               %Track{name: "Bohemian Rhapsody", artist: "Queen", provider: :spotify}
             ]
    end

    test "can search structs by atom field" do
      tracks = Search.filter(@tracks, "spotify", [:name, :provider])

      assert tracks == [
               %Track{name: "Mr. Brightside", artist: "The Killers", provider: :spotify},
               %Track{name: "Smells Like Teen Spirit", artist: "Nirvana", provider: :spotify},
               %Track{name: "Blinding Lights", artist: "The Weeknd", provider: :spotify},
               %Track{name: "HUMBLE.", artist: "Kendrick Lamar", provider: :spotify},
               %Track{name: "Bohemian Rhapsody", artist: "Queen", provider: :spotify},
               %Track{name: "Hotel California", artist: "Eagles", provider: :spotify}
             ]
    end
  end

  describe "flag/1" do
    test "does not apply with empty queries" do
      submissions = Search.flag(@submissions, [])

      assert submissions == @submissions
    end

    test "can search structs by boolean field" do
      submissions = Search.flag(@submissions, reviewed?: true)

      assert submissions == [
               %{url: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp", provider: :spotify, reviewed?: true},
               %{url: "https://www.deezer.com/track/3135556", provider: :deezer, reviewed?: true},
               %{url: "https://www.deezer.com/track/1109731", provider: :deezer, reviewed?: true},
               %{url: "https://open.spotify.com/track/6habFhsOp2NvshLv26DqMb", provider: :spotify, reviewed?: true},
               %{url: "https://open.spotify.com/track/2takcwOaAZWiXQijPHIx7B", provider: :spotify, reviewed?: true},
               %{url: "https://open.spotify.com/track/1AhDOtG9vPSOmsWgNW0BEY", provider: :spotify, reviewed?: true}
             ]
    end
  end

  describe "sort/1" do
    test "?" do
      unsorted_submissions = [
        %{url: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp", added_at: "2025-08-19T14:30:00Z"},
        %{url: "https://open.spotify.com/track/7GhIk7Il098yCjg4BQjzvb", added_at: "2024-12-01T09:15:00Z"},
        %{url: "https://www.deezer.com/track/3135556", added_at: "2025-01-22T20:45:00Z"},
        %{url: "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b", added_at: "2023-11-10T12:00:00Z"},
        %{url: "https://www.deezer.com/track/1109731", added_at: "2025-06-05T18:20:00Z"}
      ]

      submissions = Search.sort(unsorted_submissions, :added_at, :asc)

      assert submissions == [
               %{url: "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b", added_at: "2023-11-10T12:00:00Z"},
               %{url: "https://open.spotify.com/track/7GhIk7Il098yCjg4BQjzvb", added_at: "2024-12-01T09:15:00Z"},
               %{url: "https://www.deezer.com/track/3135556", added_at: "2025-01-22T20:45:00Z"},
               %{url: "https://www.deezer.com/track/1109731", added_at: "2025-06-05T18:20:00Z"},
               %{url: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp", added_at: "2025-08-19T14:30:00Z"}
             ]
    end
  end
end
