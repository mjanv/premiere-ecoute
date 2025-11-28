defmodule PremiereEcoute.Discography.AlbumFixtures do
  @moduledoc """
  Album fixtures.

  Provides factory functions to generate test album structs with associated tracks for use in test suites.
  """

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Generates test album struct with default attributes and tracks.

  Creates a generic album fixture with sample track data, merging provided attributes to override defaults for testing.
  """
  @spec album_fixture(map()) :: Album.t()
  def album_fixture(attrs \\ %{}) do
    %{
      provider: :spotify,
      album_id: "album123",
      name: "Sample Album",
      artist: "Sample Artist",
      release_date: ~D[2023-01-01],
      cover_url: "http://example.com/cover.jpg",
      total_tracks: 2,
      tracks: [
        %Track{provider: :spotify, track_id: "track001", name: "Track One", track_number: 1, duration_ms: 210_000},
        %Track{provider: :spotify, track_id: "track002", name: "Track Two", track_number: 2, duration_ms: 180_000}
      ]
    }
    |> Map.merge(attrs)
    |> then(fn attrs -> struct(Album, attrs) end)
  end

  @doc """
  Returns Billie Eilish "HIT ME HARD AND SOFT" album fixture for testing.

  Provides complete Spotify album fixture with 10 tracks and real metadata from the 2024 album for integration tests.
  """
  @spec spotify_album_fixture(String.t()) :: Album.t()
  def spotify_album_fixture("7aJuG4TFXa2hmE4z1yxc3n") do
    %Album{
      provider: :spotify,
      name: "HIT ME HARD AND SOFT",
      artist: "Billie Eilish",
      album_id: "7aJuG4TFXa2hmE4z1yxc3n",
      cover_url: "https://i.scdn.co/image/ab67616d00001e0271d62ea7ea8a5be92d3c1f62",
      release_date: ~D[2024-05-17],
      total_tracks: 10,
      tracks: [
        %Track{provider: :spotify, name: "SKINNY", track_id: "1CsMKhwEmNnmvHUuO5nryA", duration_ms: 219_733, track_number: 1},
        %Track{provider: :spotify, name: "LUNCH", track_id: "629DixmZGHc7ILtEntuiWE", duration_ms: 179_586, track_number: 2},
        %Track{provider: :spotify, name: "CHIHIRO", track_id: "7BRD7x5pt8Lqa1eGYC4dzj", duration_ms: 303_440, track_number: 3},
        %Track{
          provider: :spotify,
          name: "BIRDS OF A FEATHER",
          track_id: "6dOtVTDdiauQNBQEDOtlAB",
          duration_ms: 210_373,
          track_number: 4
        },
        %Track{provider: :spotify, name: "WILDFLOWER", track_id: "3QaPy1KgI7nu9FJEQUgn6h", duration_ms: 261_466, track_number: 5},
        %Track{
          provider: :spotify,
          name: "THE GREATEST",
          track_id: "6TGd66r0nlPaYm3KIoI7ET",
          duration_ms: 293_840,
          track_number: 6
        },
        %Track{
          provider: :spotify,
          name: "L’AMOUR DE MA VIE",
          track_id: "6fPan2saHdFaIHuTSatORv",
          duration_ms: 333_986,
          track_number: 7
        },
        %Track{provider: :spotify, name: "THE DINER", track_id: "1LLUoftvmTjVNBHZoQyveF", duration_ms: 186_346, track_number: 8},
        %Track{
          provider: :spotify,
          name: "BITTERSUITE",
          track_id: "7DpUoxGSdlDHfqCYj0otzU",
          duration_ms: 298_440,
          track_number: 9
        },
        %Track{provider: :spotify, name: "BLUE", track_id: "2prqm9sPLj10B4Wg0wE5x9", duration_ms: 343_120, track_number: 10}
      ]
    }
  end

  def spotify_album_fixture("5tzRuO6GP7WRvP3rEOPAO9") do
    %Album{
      provider: :spotify,
      name: "Happier Than Ever",
      artist: "Billie Eilish",
      cover_url: "https://i.scdn.co/image/ab67616d00001e02e1317227c6c759e01beae66e",
      release_date: ~D[2021-07-30],
      album_id: "5tzRuO6GP7WRvP3rEOPAO9",
      total_tracks: 16,
      tracks: [
        %Track{
          provider: :spotify,
          name: "Getting Older",
          track_id: "42dosBqMOdtgxKw0KRFJF0",
          duration_ms: 244_221,
          track_number: 1
        },
        %Track{
          provider: :spotify,
          name: "I Didn't Change My Number",
          track_id: "1YWktsdm9IPZPyqVv1T8XS",
          duration_ms: 158_463,
          track_number: 2
        },
        %Track{
          provider: :spotify,
          name: "Billie Bossa Nova",
          track_id: "2M4uqoBmF1vkhqDCTDS0M5",
          duration_ms: 196_730,
          track_number: 3
        },
        %Track{provider: :spotify, name: "my future", track_id: "3w1Gt4zARUcd49De9okdiG", duration_ms: 210_005, track_number: 4},
        %Track{provider: :spotify, name: "Oxytocin", track_id: "0UJAH9v2PmS7sBcuBquprR", duration_ms: 210_232, track_number: 5},
        %Track{provider: :spotify, name: "GOLDWING", track_id: "3YO70voBXbq5ZsBxMtSN9h", duration_ms: 151_536, track_number: 6},
        %Track{provider: :spotify, name: "Lost Cause", track_id: "1LdXpFzKjF7Jz6jA82DYs0", duration_ms: 212_496, track_number: 7},
        %Track{
          provider: :spotify,
          name: "Halley's Comet",
          track_id: "6MtqlolOMza4ehwgsAFJW7",
          duration_ms: 234_761,
          track_number: 8
        },
        %Track{
          provider: :spotify,
          name: "Not My Responsibility",
          track_id: "5C7K3RtgBbMW6HmO5v3Pk3",
          duration_ms: 227_679,
          track_number: 9
        },
        %Track{
          provider: :spotify,
          name: "OverHeated",
          track_id: "2ai00L1P6imz6RQ47gVLlm",
          duration_ms: 214_058,
          track_number: 10
        },
        %Track{
          provider: :spotify,
          name: "Everybody Dies",
          track_id: "5pPga39odaQTwY0Y5HVWfF",
          duration_ms: 206_622,
          track_number: 11
        },
        %Track{
          provider: :spotify,
          name: "Your Power",
          track_id: "4XMWUYh2Y8TthKzu6NIRtF",
          duration_ms: 245_896,
          track_number: 12
        },
        %Track{provider: :spotify, name: "NDA", track_id: "0JdOW3PNgjpMAMNL4qOhe6", duration_ms: 195_776, track_number: 13},
        %Track{
          provider: :spotify,
          name: "Therefore I Am",
          track_id: "1jH0zv5AstiEumMGIlygQo",
          duration_ms: 173_539,
          track_number: 14
        },
        %Track{
          provider: :spotify,
          name: "Happier Than Ever",
          track_id: "0gLXF5LtNkqDoeVVGjCsEu",
          duration_ms: 298_899,
          track_number: 15
        },
        %Track{
          provider: :spotify,
          name: "Male Fantasy",
          track_id: "13lUUFsU6GMvRDN432qKxX",
          duration_ms: 194_886,
          track_number: 16
        }
      ]
    }
  end

  def spotify_album_fixture("0S0KGZnfBGSIssfF54WSJh") do
    %Album{
      provider: :spotify,
      name: "WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?",
      artist: "Billie Eilish",
      cover_url: "https://i.scdn.co/image/ab67616d00001e0250a3147b4edd7701a876c6ce",
      release_date: ~D[2019-03-29],
      album_id: "0S0KGZnfBGSIssfF54WSJh",
      total_tracks: 14,
      tracks: [
        %Track{provider: :spotify, name: "!!!!!!!", track_id: "0rQtoQXQfwpDW0c7Fw1NeM", duration_ms: 13_578, track_number: 1},
        %Track{provider: :spotify, name: "bad guy", track_id: "2Fxmhks0bxGSBdJ92vM42m", duration_ms: 194_087, track_number: 2},
        %Track{provider: :spotify, name: "xanny", track_id: "4QIo4oxwzzafcBWkKjDpXY", duration_ms: 243_725, track_number: 3},
        %Track{
          provider: :spotify,
          name: "you should see me in a crown",
          track_id: "3XF5xLJHOQQRbWya6hBp7d",
          duration_ms: 180_952,
          track_number: 4
        },
        %Track{
          provider: :spotify,
          name: "all the good girls go to hell",
          track_id: "6IRdLKIyS4p7XNiP8r6rsx",
          duration_ms: 168_839,
          track_number: 5
        },
        %Track{
          provider: :spotify,
          name: "wish you were gay",
          track_id: "3Fj47GNK2kUF0uaEDgXLaD",
          duration_ms: 221_543,
          track_number: 6
        },
        %Track{
          provider: :spotify,
          name: "when the party's over",
          track_id: "43zdsphuZLzwA9k4DJhU0I",
          duration_ms: 196_077,
          track_number: 7
        },
        %Track{provider: :spotify, name: "8", track_id: "6X29iaaazwho3ab7GNue5r", duration_ms: 173_201, track_number: 8},
        %Track{
          provider: :spotify,
          name: "my strange addiction",
          track_id: "3Tc57t9l2O8FwQZtQOvPXK",
          duration_ms: 179_889,
          track_number: 9
        },
        %Track{
          provider: :spotify,
          name: "bury a friend",
          track_id: "4SSnFejRGlZikf02HLewEF",
          duration_ms: 193_143,
          track_number: 10
        },
        %Track{provider: :spotify, name: "ilomilo", track_id: "7qEKqBCD2vE5vIBsrUitpD", duration_ms: 156_370, track_number: 11},
        %Track{
          provider: :spotify,
          name: "listen before i go",
          track_id: "0tMSssfxAL2oV8Vri0mFHE",
          duration_ms: 242_652,
          track_number: 12
        },
        %Track{
          provider: :spotify,
          name: "i love you",
          track_id: "6CcJMwBtXByIz4zQLzFkKc",
          duration_ms: 291_796,
          track_number: 13
        },
        %Track{provider: :spotify, name: "goodbye", track_id: "3LgWsmilsrWXiPYQFRD0T7", duration_ms: 119_409, track_number: 14}
      ]
    }
  end
end
