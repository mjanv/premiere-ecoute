defmodule PremiereEcoute.Apis.Players.PlaybackStateTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.Players.PlaybackState

  @raw_playing %{
    "device" => %{
      "id" => "894316073d99195e07d06a87454e0132508f4f24",
      "is_active" => true,
      "is_private_session" => false,
      "is_restricted" => false,
      "name" => "FRACTAL",
      "type" => "Computer",
      "volume_percent" => 53,
      "supports_volume" => true
    },
    "repeat_state" => "off",
    "shuffle_state" => false,
    "context" => nil,
    "timestamp" => 1_782_167_272_952,
    "progress_ms" => 17_399,
    "is_playing" => true,
    "item" => %{
      "album" => %{
        "album_type" => "album",
        "name" => "DISCO INFERNO",
        "uri" => "spotify:album:7t1h5yn1S2JBCGrX0vUkTl",
        "artists" => [%{"name" => "LinLin"}]
      },
      "artists" => [
        %{
          "external_urls" => %{"spotify" => "https://open.spotify.com/artist/1D7nUBd4i2mrVpmLQmHI0n"},
          "href" => "https://api.spotify.com/v1/artists/1D7nUBd4i2mrVpmLQmHI0n",
          "id" => "1D7nUBd4i2mrVpmLQmHI0n",
          "name" => "LinLin",
          "type" => "artist",
          "uri" => "spotify:artist:1D7nUBd4i2mrVpmLQmHI0n"
        }
      ],
      "duration_ms" => 158_229,
      "explicit" => true,
      "id" => "2tLRre8Tb3vsTptDvZzCaL",
      "name" => "BLACC*",
      "track_number" => 2,
      "uri" => "spotify:track:2tLRre8Tb3vsTptDvZzCaL",
      "is_local" => false
    },
    "currently_playing_type" => "track",
    "actions" => %{"disallows" => %{"resuming" => true, "skipping_prev" => true}},
    "smart_shuffle" => false
  }

  @raw_single %{
    "device" => %{
      "id" => "894316073d99195e07d06a87454e0132508f4f24",
      "is_active" => true,
      "is_private_session" => false,
      "is_restricted" => false,
      "name" => "FRACTAL",
      "type" => "Computer",
      "volume_percent" => 53,
      "supports_volume" => true
    },
    "repeat_state" => "off",
    "shuffle_state" => false,
    "context" => nil,
    "timestamp" => 1_782_167_573_296,
    "progress_ms" => 3_824,
    "is_playing" => true,
    "item" => %{
      "album" => %{
        "album_type" => "single",
        "name" => "What You Want",
        "uri" => "spotify:album:0PWDYw8t6pEp4n8sFHZzOj",
        "artists" => [%{"name" => "Angèle"}, %{"name" => "Justice"}]
      },
      "artists" => [
        %{
          "external_urls" => %{"spotify" => "https://open.spotify.com/artist/3QVolfxko2UyCOtexhVTli"},
          "href" => "https://api.spotify.com/v1/artists/3QVolfxko2UyCOtexhVTli",
          "id" => "3QVolfxko2UyCOtexhVTli",
          "name" => "Angèle",
          "type" => "artist",
          "uri" => "spotify:artist:3QVolfxko2UyCOtexhVTli"
        },
        %{
          "external_urls" => %{"spotify" => "https://open.spotify.com/artist/1gR0gsQYfi6joyO1dlp76N"},
          "href" => "https://api.spotify.com/v1/artists/1gR0gsQYfi6joyO1dlp76N",
          "id" => "1gR0gsQYfi6joyO1dlp76N",
          "name" => "Justice",
          "type" => "artist",
          "uri" => "spotify:artist:1gR0gsQYfi6joyO1dlp76N"
        }
      ],
      "duration_ms" => 188_320,
      "explicit" => false,
      "id" => "7J4dPn4Xg9Op0e8N2tjqkX",
      "name" => "What You Want",
      "track_number" => 1,
      "uri" => "spotify:track:7J4dPn4Xg9Op0e8N2tjqkX",
      "is_local" => false
    },
    "currently_playing_type" => "track",
    "actions" => %{"disallows" => %{"resuming" => true, "skipping_prev" => true}},
    "smart_shuffle" => false
  }

  describe "from_json/1" do
    test "converts a playing state with device and item" do
      assert PlaybackState.from_json(@raw_playing) == %PlaybackState{
               is_playing: true,
               progress_ms: 17_399,
               device: %{name: "FRACTAL", is_active: true},
               item: %{
                 uri: "spotify:track:2tLRre8Tb3vsTptDvZzCaL",
                 name: "BLACC*",
                 duration_ms: 158_229,
                 artists: [%{name: "LinLin"}],
                 type: :album,
                 track_number: 2,
                 album: %{name: "DISCO INFERNO", total_tracks: nil, images: []}
               }
             }
    end

    test "converts a single with multiple artists" do
      assert PlaybackState.from_json(@raw_single) == %PlaybackState{
               is_playing: true,
               progress_ms: 3_824,
               device: %{name: "FRACTAL", is_active: true},
               item: %{
                 uri: "spotify:track:7J4dPn4Xg9Op0e8N2tjqkX",
                 name: "What You Want",
                 duration_ms: 188_320,
                 artists: [%{name: "Angèle"}, %{name: "Justice"}],
                 type: :single,
                 track_number: 1,
                 album: %{name: "What You Want", total_tracks: nil, images: []}
               }
             }
    end

    test "converts a non-playing state with no device" do
      raw = %{"is_playing" => false, "progress_ms" => 0, "device" => nil, "item" => nil}

      assert PlaybackState.from_json(raw) == %PlaybackState{
               is_playing: false,
               progress_ms: 0,
               device: nil,
               item: nil
             }
    end
  end
end
