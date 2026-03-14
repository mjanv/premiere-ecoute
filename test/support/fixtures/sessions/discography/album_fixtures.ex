defmodule PremiereEcoute.Discography.AlbumFixtures do
  @moduledoc """
  Album fixtures.

  Provides factory functions to generate test album structs with associated tracks for use in test suites.
  """

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist

  @doc """
  Generates test album struct with default attributes and tracks.

  Creates a generic album fixture with sample track data, merging provided attributes to override defaults for testing.
  """
  @spec album_fixture(map()) :: Album.t()
  def album_fixture(attrs \\ %{}) do
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Sample Artist"})

    %{
      provider_ids: %{spotify: "album123"},
      name: "Sample Album",
      artists: [artist],
      release_date: ~D[2023-01-01],
      cover_url: "http://example.com/cover.jpg",
      total_tracks: 2,
      tracks: [
        %Track{provider_ids: %{spotify: "track001"}, name: "Track One", track_number: 1, duration_ms: 210_000},
        %Track{provider_ids: %{spotify: "track002"}, name: "Track Two", track_number: 2, duration_ms: 180_000}
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
      provider_ids: %{spotify: "7aJuG4TFXa2hmE4z1yxc3n"},
      name: "HIT ME HARD AND SOFT",
      artists: [%Artist{name: "Billie Eilish"}],
      cover_url: "https://i.scdn.co/image/ab67616d00001e0271d62ea7ea8a5be92d3c1f62",
      release_date: ~D[2024-05-17],
      total_tracks: 10,
      tracks: [
        %Track{provider_ids: %{spotify: "1CsMKhwEmNnmvHUuO5nryA"}, name: "SKINNY", duration_ms: 219_733, track_number: 1},
        %Track{provider_ids: %{spotify: "629DixmZGHc7ILtEntuiWE"}, name: "LUNCH", duration_ms: 179_586, track_number: 2},
        %Track{provider_ids: %{spotify: "7BRD7x5pt8Lqa1eGYC4dzj"}, name: "CHIHIRO", duration_ms: 303_440, track_number: 3},
        %Track{
          provider_ids: %{spotify: "6dOtVTDdiauQNBQEDOtlAB"},
          name: "BIRDS OF A FEATHER",
          duration_ms: 210_373,
          track_number: 4
        },
        %Track{provider_ids: %{spotify: "3QaPy1KgI7nu9FJEQUgn6h"}, name: "WILDFLOWER", duration_ms: 261_466, track_number: 5},
        %Track{provider_ids: %{spotify: "6TGd66r0nlPaYm3KIoI7ET"}, name: "THE GREATEST", duration_ms: 293_840, track_number: 6},
        %Track{
          provider_ids: %{spotify: "6fPan2saHdFaIHuTSatORv"},
          name: "L'AMOUR DE MA VIE",
          duration_ms: 333_986,
          track_number: 7
        },
        %Track{provider_ids: %{spotify: "1LLUoftvmTjVNBHZoQyveF"}, name: "THE DINER", duration_ms: 186_346, track_number: 8},
        %Track{provider_ids: %{spotify: "7DpUoxGSdlDHfqCYj0otzU"}, name: "BITTERSUITE", duration_ms: 298_440, track_number: 9},
        %Track{provider_ids: %{spotify: "2prqm9sPLj10B4Wg0wE5x9"}, name: "BLUE", duration_ms: 343_120, track_number: 10}
      ]
    }
  end

  def spotify_album_fixture("5tzRuO6GP7WRvP3rEOPAO9") do
    %Album{
      provider_ids: %{spotify: "5tzRuO6GP7WRvP3rEOPAO9"},
      name: "Happier Than Ever",
      artists: [%Artist{name: "Billie Eilish"}],
      cover_url: "https://i.scdn.co/image/ab67616d00001e02e1317227c6c759e01beae66e",
      release_date: ~D[2021-07-30],
      total_tracks: 16,
      tracks: [
        %Track{provider_ids: %{spotify: "42dosBqMOdtgxKw0KRFJF0"}, name: "Getting Older", duration_ms: 244_221, track_number: 1},
        %Track{
          provider_ids: %{spotify: "1YWktsdm9IPZPyqVv1T8XS"},
          name: "I Didn't Change My Number",
          duration_ms: 158_463,
          track_number: 2
        },
        %Track{
          provider_ids: %{spotify: "2M4uqoBmF1vkhqDCTDS0M5"},
          name: "Billie Bossa Nova",
          duration_ms: 196_730,
          track_number: 3
        },
        %Track{provider_ids: %{spotify: "3w1Gt4zARUcd49De9okdiG"}, name: "my future", duration_ms: 210_005, track_number: 4},
        %Track{provider_ids: %{spotify: "0UJAH9v2PmS7sBcuBquprR"}, name: "Oxytocin", duration_ms: 210_232, track_number: 5},
        %Track{provider_ids: %{spotify: "3YO70voBXbq5ZsBxMtSN9h"}, name: "GOLDWING", duration_ms: 151_536, track_number: 6},
        %Track{provider_ids: %{spotify: "1LdXpFzKjF7Jz6jA82DYs0"}, name: "Lost Cause", duration_ms: 212_496, track_number: 7},
        %Track{provider_ids: %{spotify: "6MtqlolOMza4ehwgsAFJW7"}, name: "Halley's Comet", duration_ms: 234_761, track_number: 8},
        %Track{
          provider_ids: %{spotify: "5C7K3RtgBbMW6HmO5v3Pk3"},
          name: "Not My Responsibility",
          duration_ms: 227_679,
          track_number: 9
        },
        %Track{provider_ids: %{spotify: "2ai00L1P6imz6RQ47gVLlm"}, name: "OverHeated", duration_ms: 214_058, track_number: 10},
        %Track{
          provider_ids: %{spotify: "5pPga39odaQTwY0Y5HVWfF"},
          name: "Everybody Dies",
          duration_ms: 206_622,
          track_number: 11
        },
        %Track{provider_ids: %{spotify: "4XMWUYh2Y8TthKzu6NIRtF"}, name: "Your Power", duration_ms: 245_896, track_number: 12},
        %Track{provider_ids: %{spotify: "0JdOW3PNgjpMAMNL4qOhe6"}, name: "NDA", duration_ms: 195_776, track_number: 13},
        %Track{
          provider_ids: %{spotify: "1jH0zv5AstiEumMGIlygQo"},
          name: "Therefore I Am",
          duration_ms: 173_539,
          track_number: 14
        },
        %Track{
          provider_ids: %{spotify: "0gLXF5LtNkqDoeVVGjCsEu"},
          name: "Happier Than Ever",
          duration_ms: 298_899,
          track_number: 15
        },
        %Track{provider_ids: %{spotify: "13lUUFsU6GMvRDN432qKxX"}, name: "Male Fantasy", duration_ms: 194_886, track_number: 16}
      ]
    }
  end

  def spotify_album_fixture("0S0KGZnfBGSIssfF54WSJh") do
    %Album{
      provider_ids: %{spotify: "0S0KGZnfBGSIssfF54WSJh"},
      name: "WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?",
      artists: [%Artist{name: "Billie Eilish"}],
      cover_url: "https://i.scdn.co/image/ab67616d00001e0250a3147b4edd7701a876c6ce",
      release_date: ~D[2019-03-29],
      total_tracks: 14,
      tracks: [
        %Track{provider_ids: %{spotify: "0rQtoQXQfwpDW0c7Fw1NeM"}, name: "!!!!!!!", duration_ms: 13_578, track_number: 1},
        %Track{provider_ids: %{spotify: "2Fxmhks0bxGSBdJ92vM42m"}, name: "bad guy", duration_ms: 194_087, track_number: 2},
        %Track{provider_ids: %{spotify: "4QIo4oxwzzafcBWkKjDpXY"}, name: "xanny", duration_ms: 243_725, track_number: 3},
        %Track{
          provider_ids: %{spotify: "3XF5xLJHOQQRbWya6hBp7d"},
          name: "you should see me in a crown",
          duration_ms: 180_952,
          track_number: 4
        },
        %Track{
          provider_ids: %{spotify: "6IRdLKIyS4p7XNiP8r6rsx"},
          name: "all the good girls go to hell",
          duration_ms: 168_839,
          track_number: 5
        },
        %Track{
          provider_ids: %{spotify: "3Fj47GNK2kUF0uaEDgXLaD"},
          name: "wish you were gay",
          duration_ms: 221_543,
          track_number: 6
        },
        %Track{
          provider_ids: %{spotify: "43zdsphuZLzwA9k4DJhU0I"},
          name: "when the party's over",
          duration_ms: 196_077,
          track_number: 7
        },
        %Track{provider_ids: %{spotify: "6X29iaaazwho3ab7GNue5r"}, name: "8", duration_ms: 173_201, track_number: 8},
        %Track{
          provider_ids: %{spotify: "3Tc57t9l2O8FwQZtQOvPXK"},
          name: "my strange addiction",
          duration_ms: 179_889,
          track_number: 9
        },
        %Track{provider_ids: %{spotify: "4SSnFejRGlZikf02HLewEF"}, name: "bury a friend", duration_ms: 193_143, track_number: 10},
        %Track{provider_ids: %{spotify: "7qEKqBCD2vE5vIBsrUitpD"}, name: "ilomilo", duration_ms: 156_370, track_number: 11},
        %Track{
          provider_ids: %{spotify: "0tMSssfxAL2oV8Vri0mFHE"},
          name: "listen before i go",
          duration_ms: 242_652,
          track_number: 12
        },
        %Track{provider_ids: %{spotify: "6CcJMwBtXByIz4zQLzFkKc"}, name: "i love you", duration_ms: 291_796, track_number: 13},
        %Track{provider_ids: %{spotify: "3LgWsmilsrWXiPYQFRD0T7"}, name: "goodbye", duration_ms: 119_409, track_number: 14}
      ]
    }
  end
end
