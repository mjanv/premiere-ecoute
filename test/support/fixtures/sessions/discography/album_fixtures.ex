defmodule PremiereEcoute.Sessions.Discography.AlbumFixtures do
  @moduledoc false

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Track

  def album_fixture(attrs \\ %{}) do
    %{
      spotify_id: "album123",
      name: "Sample Album",
      artist: "Sample Artist",
      release_date: ~D[2023-01-01],
      cover_url: "http://example.com/cover.jpg",
      total_tracks: 2,
      tracks: [
        %Track{spotify_id: "track001", name: "Track One", track_number: 1, duration_ms: 210_000},
        %Track{spotify_id: "track002", name: "Track Two", track_number: 2, duration_ms: 180_000}
      ]
    }
    |> Map.merge(attrs)
    |> then(fn attrs -> struct(Album, attrs) end)
  end

  def spotify_album_fixture("7aJuG4TFXa2hmE4z1yxc3n") do
    %Album{
      name: "HIT ME HARD AND SOFT",
      artist: "Billie Eilish",
      spotify_id: "7aJuG4TFXa2hmE4z1yxc3n",
      cover_url: "https://i.scdn.co/image/ab67616d00001e0271d62ea7ea8a5be92d3c1f62",
      release_date: ~D[2024-05-17],
      total_tracks: 10,
      tracks: [
        %Track{name: "SKINNY", spotify_id: "1CsMKhwEmNnmvHUuO5nryA", duration_ms: 219_733, track_number: 1},
        %Track{name: "LUNCH", spotify_id: "629DixmZGHc7ILtEntuiWE", duration_ms: 179_586, track_number: 2},
        %Track{name: "CHIHIRO", spotify_id: "7BRD7x5pt8Lqa1eGYC4dzj", duration_ms: 303_440, track_number: 3},
        %Track{name: "BIRDS OF A FEATHER", spotify_id: "6dOtVTDdiauQNBQEDOtlAB", duration_ms: 210_373, track_number: 4},
        %Track{name: "WILDFLOWER", spotify_id: "3QaPy1KgI7nu9FJEQUgn6h", duration_ms: 261_466, track_number: 5},
        %Track{name: "THE GREATEST", spotify_id: "6TGd66r0nlPaYm3KIoI7ET", duration_ms: 293_840, track_number: 6},
        %Track{name: "L’AMOUR DE MA VIE", spotify_id: "6fPan2saHdFaIHuTSatORv", duration_ms: 333_986, track_number: 7},
        %Track{name: "THE DINER", spotify_id: "1LLUoftvmTjVNBHZoQyveF", duration_ms: 186_346, track_number: 8},
        %Track{name: "BITTERSUITE", spotify_id: "7DpUoxGSdlDHfqCYj0otzU", duration_ms: 298_440, track_number: 9},
        %Track{name: "BLUE", spotify_id: "2prqm9sPLj10B4Wg0wE5x9", duration_ms: 343_120, track_number: 10}
      ]
    }
  end

  def spotify_album_fixture("5tzRuO6GP7WRvP3rEOPAO9") do
    %Album{
      name: "Happier Than Ever",
      artist: "Billie Eilish",
      cover_url: "https://i.scdn.co/image/ab67616d00001e02e1317227c6c759e01beae66e",
      release_date: ~D[2021-07-30],
      spotify_id: "5tzRuO6GP7WRvP3rEOPAO9",
      total_tracks: 16,
      tracks: [
        %Track{name: "Getting Older", spotify_id: "42dosBqMOdtgxKw0KRFJF0", duration_ms: 244_221, track_number: 1},
        %Track{name: "I Didn't Change My Number", spotify_id: "1YWktsdm9IPZPyqVv1T8XS", duration_ms: 158_463, track_number: 2},
        %Track{name: "Billie Bossa Nova", spotify_id: "2M4uqoBmF1vkhqDCTDS0M5", duration_ms: 196_730, track_number: 3},
        %Track{name: "my future", spotify_id: "3w1Gt4zARUcd49De9okdiG", duration_ms: 210_005, track_number: 4},
        %Track{name: "Oxytocin", spotify_id: "0UJAH9v2PmS7sBcuBquprR", duration_ms: 210_232, track_number: 5},
        %Track{name: "GOLDWING", spotify_id: "3YO70voBXbq5ZsBxMtSN9h", duration_ms: 151_536, track_number: 6},
        %Track{name: "Lost Cause", spotify_id: "1LdXpFzKjF7Jz6jA82DYs0", duration_ms: 212_496, track_number: 7},
        %Track{name: "Halley's Comet", spotify_id: "6MtqlolOMza4ehwgsAFJW7", duration_ms: 234_761, track_number: 8},
        %Track{name: "Not My Responsibility", spotify_id: "5C7K3RtgBbMW6HmO5v3Pk3", duration_ms: 227_679, track_number: 9},
        %Track{name: "OverHeated", spotify_id: "2ai00L1P6imz6RQ47gVLlm", duration_ms: 214_058, track_number: 10},
        %Track{name: "Everybody Dies", spotify_id: "5pPga39odaQTwY0Y5HVWfF", duration_ms: 206_622, track_number: 11},
        %Track{name: "Your Power", spotify_id: "4XMWUYh2Y8TthKzu6NIRtF", duration_ms: 245_896, track_number: 12},
        %Track{name: "NDA", spotify_id: "0JdOW3PNgjpMAMNL4qOhe6", duration_ms: 195_776, track_number: 13},
        %Track{name: "Therefore I Am", spotify_id: "1jH0zv5AstiEumMGIlygQo", duration_ms: 173_539, track_number: 14},
        %Track{name: "Happier Than Ever", spotify_id: "0gLXF5LtNkqDoeVVGjCsEu", duration_ms: 298_899, track_number: 15},
        %Track{name: "Male Fantasy", spotify_id: "13lUUFsU6GMvRDN432qKxX", duration_ms: 194_886, track_number: 16}
      ]
    }
  end

  def spotify_album_fixture("0S0KGZnfBGSIssfF54WSJh") do
    %Album{
      name: "WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?",
      artist: "Billie Eilish",
      cover_url: "https://i.scdn.co/image/ab67616d00001e0250a3147b4edd7701a876c6ce",
      release_date: ~D[2019-03-29],
      spotify_id: "0S0KGZnfBGSIssfF54WSJh",
      total_tracks: 14,
      tracks: [
        %Track{name: "!!!!!!!", spotify_id: "0rQtoQXQfwpDW0c7Fw1NeM", duration_ms: 13_578, track_number: 1},
        %Track{name: "bad guy", spotify_id: "2Fxmhks0bxGSBdJ92vM42m", duration_ms: 194_087, track_number: 2},
        %Track{name: "xanny", spotify_id: "4QIo4oxwzzafcBWkKjDpXY", duration_ms: 243_725, track_number: 3},
        %Track{name: "you should see me in a crown", spotify_id: "3XF5xLJHOQQRbWya6hBp7d", duration_ms: 180_952, track_number: 4},
        %Track{
          name: "all the good girls go to hell",
          spotify_id: "6IRdLKIyS4p7XNiP8r6rsx",
          duration_ms: 168_839,
          track_number: 5
        },
        %Track{name: "wish you were gay", spotify_id: "3Fj47GNK2kUF0uaEDgXLaD", duration_ms: 221_543, track_number: 6},
        %Track{name: "when the party's over", spotify_id: "43zdsphuZLzwA9k4DJhU0I", duration_ms: 196_077, track_number: 7},
        %Track{name: "8", spotify_id: "6X29iaaazwho3ab7GNue5r", duration_ms: 173_201, track_number: 8},
        %Track{name: "my strange addiction", spotify_id: "3Tc57t9l2O8FwQZtQOvPXK", duration_ms: 179_889, track_number: 9},
        %Track{name: "bury a friend", spotify_id: "4SSnFejRGlZikf02HLewEF", duration_ms: 193_143, track_number: 10},
        %Track{name: "ilomilo", spotify_id: "7qEKqBCD2vE5vIBsrUitpD", duration_ms: 156_370, track_number: 11},
        %Track{name: "listen before i go", spotify_id: "0tMSssfxAL2oV8Vri0mFHE", duration_ms: 242_652, track_number: 12},
        %Track{name: "i love you", spotify_id: "6CcJMwBtXByIz4zQLzFkKc", duration_ms: 291_796, track_number: 13},
        %Track{name: "goodbye", spotify_id: "3LgWsmilsrWXiPYQFRD0T7", duration_ms: 119_409, track_number: 14}
      ]
    }
  end
end
