defmodule PremiereEcoute.Discography.PlaylistTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Repo

  describe "create/1" do
    test "creates an playlist with tracks" do
      {:ok, playlist} = Playlist.create(playlist_fixture())

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               owner_id: "ku296zgwbo0e3qff8cylptsjq",
               owner_name: "Flonflon",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "does not recreate an existing playlist" do
      {:ok, _} = Playlist.create(playlist_fixture())
      {:error, changeset} = Playlist.create(playlist_fixture())

      assert Repo.traverse_errors(changeset) == %{playlist_id: ["has already been taken"]}
    end
  end

  describe "create_if_not_exists/1" do
    test "create an unexisting playlist" do
      {:ok, playlist} = Playlist.create_if_not_exists(playlist_fixture())

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "does not recreate an existing playlist" do
      {:ok, _} = Playlist.create_if_not_exists(playlist_fixture())
      {:ok, playlist} = Playlist.create_if_not_exists(playlist_fixture())

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end
  end

  describe "get/1" do
    test "get an existing playlist" do
      {:ok, %Playlist{id: id}} = Playlist.create(playlist_fixture())

      playlist = Playlist.get(id)

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "get an unexisting playlist" do
      assert is_nil(Playlist.get(-1))
    end
  end

  describe "get_by/1" do
    test "get an existing playlist" do
      {:ok, %Playlist{playlist_id: playlist_id}} = Playlist.create(playlist_fixture())

      playlist = Playlist.get_by(playlist_id: playlist_id)

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "get an unexisting playlist" do
      assert is_nil(Playlist.get_by(playlist_id: "unknown"))
    end
  end

  describe "add_track_to_playlist/2" do
    @payload %{
      "actions" => %{"disallows" => %{"resuming" => true, "skipping_prev" => true}},
      "context" => %{
        "external_urls" => %{
          "spotify" => "https://open.spotify.com/playlist/7nNETRSCPHls7AXTJkF0fZ"
        },
        "href" => "https://api.spotify.com/v1/playlists/7nNETRSCPHls7AXTJkF0fZ",
        "type" => "playlist",
        "uri" => "spotify:playlist:7nNETRSCPHls7AXTJkF0fZ"
      },
      "currently_playing_type" => "track",
      "device" => %{
        "id" => "e6dd577b6e46ccbb954ff8cf9f6847d4c01802e4",
        "is_active" => true,
        "is_private_session" => false,
        "is_restricted" => false,
        "name" => "maxime-xps",
        "supports_volume" => true,
        "type" => "Computer",
        "volume_percent" => 65
      },
      "is_playing" => true,
      "item" => %{
        "album" => %{
          "album_type" => "album",
          "artists" => [
            %{
              "external_urls" => %{
                "spotify" => "https://open.spotify.com/artist/4tZwfgrHOc3mvqYlEYSvVi"
              },
              "href" => "https://api.spotify.com/v1/artists/4tZwfgrHOc3mvqYlEYSvVi",
              "id" => "4tZwfgrHOc3mvqYlEYSvVi",
              "name" => "Daft Punk",
              "type" => "artist",
              "uri" => "spotify:artist:4tZwfgrHOc3mvqYlEYSvVi"
            }
          ],
          "available_markets" => [],
          "external_urls" => %{
            "spotify" => "https://open.spotify.com/album/5uRdvUR7xCnHmUW8n64n9y"
          },
          "href" => "https://api.spotify.com/v1/albums/5uRdvUR7xCnHmUW8n64n9y",
          "id" => "5uRdvUR7xCnHmUW8n64n9y",
          "images" => [
            %{
              "height" => 640,
              "url" => "https://i.scdn.co/image/ab67616d0000b2738ac778cc7d88779f74d33311",
              "width" => 640
            },
            %{
              "height" => 300,
              "url" => "https://i.scdn.co/image/ab67616d00001e028ac778cc7d88779f74d33311",
              "width" => 300
            },
            %{
              "height" => 64,
              "url" => "https://i.scdn.co/image/ab67616d000048518ac778cc7d88779f74d33311",
              "width" => 64
            }
          ],
          "name" => "Homework",
          "release_date" => "1997-01-17",
          "release_date_precision" => "day",
          "total_tracks" => 16,
          "type" => "album",
          "uri" => "spotify:album:5uRdvUR7xCnHmUW8n64n9y"
        },
        "artists" => [
          %{
            "external_urls" => %{
              "spotify" => "https://open.spotify.com/artist/4tZwfgrHOc3mvqYlEYSvVi"
            },
            "href" => "https://api.spotify.com/v1/artists/4tZwfgrHOc3mvqYlEYSvVi",
            "id" => "4tZwfgrHOc3mvqYlEYSvVi",
            "name" => "Daft Punk",
            "type" => "artist",
            "uri" => "spotify:artist:4tZwfgrHOc3mvqYlEYSvVi"
          }
        ],
        "available_markets" => [],
        "disc_number" => 1,
        "duration_ms" => 429_533,
        "explicit" => false,
        "external_ids" => %{"isrc" => "GBDUW0600009"},
        "external_urls" => %{
          "spotify" => "https://open.spotify.com/track/1pKYYY0dkg23sQQXi0Q5zN"
        },
        "href" => "https://api.spotify.com/v1/tracks/1pKYYY0dkg23sQQXi0Q5zN",
        "id" => "1pKYYY0dkg23sQQXi0Q5zN",
        "is_local" => false,
        "name" => "Around the World",
        "popularity" => 73,
        "preview_url" => nil,
        "track_number" => 7,
        "type" => "track",
        "uri" => "spotify:track:1pKYYY0dkg23sQQXi0Q5zN"
      },
      "progress_ms" => 4388,
      "repeat_state" => "off",
      "shuffle_state" => false,
      "smart_shuffle" => false,
      "timestamp" => 1_757_014_333_601
    }

    @payload2 %{
      "actions" => %{"disallows" => %{"resuming" => true}},
      "context" => %{
        "external_urls" => %{
          "spotify" => "https://open.spotify.com/playlist/7nNETRSCPHls7AXTJkF0fZ"
        },
        "href" => "https://api.spotify.com/v1/playlists/7nNETRSCPHls7AXTJkF0fZ",
        "type" => "playlist",
        "uri" => "spotify:playlist:7nNETRSCPHls7AXTJkF0fZ"
      },
      "currently_playing_type" => "track",
      "device" => %{
        "id" => "e6dd577b6e46ccbb954ff8cf9f6847d4c01802e4",
        "is_active" => true,
        "is_private_session" => false,
        "is_restricted" => false,
        "name" => "maxime-xps",
        "supports_volume" => true,
        "type" => "Computer",
        "volume_percent" => 65
      },
      "is_playing" => true,
      "item" => %{
        "album" => %{
          "album_type" => "album",
          "artists" => [
            %{
              "external_urls" => %{
                "spotify" => "https://open.spotify.com/artist/3koiLjNrgRTNbOwViDipeA"
              },
              "href" => "https://api.spotify.com/v1/artists/3koiLjNrgRTNbOwViDipeA",
              "id" => "3koiLjNrgRTNbOwViDipeA",
              "name" => "Marvin Gaye",
              "type" => "artist",
              "uri" => "spotify:artist:3koiLjNrgRTNbOwViDipeA"
            },
            %{
              "external_urls" => %{
                "spotify" => "https://open.spotify.com/artist/75jNCko3SnEMI5gwGqrbb8"
              },
              "href" => "https://api.spotify.com/v1/artists/75jNCko3SnEMI5gwGqrbb8",
              "id" => "75jNCko3SnEMI5gwGqrbb8",
              "name" => "Tammi Terrell",
              "type" => "artist",
              "uri" => "spotify:artist:75jNCko3SnEMI5gwGqrbb8"
            }
          ],
          "available_markets" => [],
          "external_urls" => %{
            "spotify" => "https://open.spotify.com/album/5LqviduT0g0J0ypFrFSwCE"
          },
          "href" => "https://api.spotify.com/v1/albums/5LqviduT0g0J0ypFrFSwCE",
          "id" => "5LqviduT0g0J0ypFrFSwCE",
          "images" => [
            %{
              "height" => 640,
              "url" => "https://i.scdn.co/image/ab67616d0000b2739173e50e99bdea2400222f02",
              "width" => 640
            },
            %{
              "height" => 300,
              "url" => "https://i.scdn.co/image/ab67616d00001e029173e50e99bdea2400222f02",
              "width" => 300
            },
            %{
              "height" => 64,
              "url" => "https://i.scdn.co/image/ab67616d000048519173e50e99bdea2400222f02",
              "width" => 64
            }
          ],
          "name" => "United",
          "release_date" => "1967-08-29",
          "release_date_precision" => "day",
          "total_tracks" => 12,
          "type" => "album",
          "uri" => "spotify:album:5LqviduT0g0J0ypFrFSwCE"
        },
        "artists" => [
          %{
            "external_urls" => %{
              "spotify" => "https://open.spotify.com/artist/3koiLjNrgRTNbOwViDipeA"
            },
            "href" => "https://api.spotify.com/v1/artists/3koiLjNrgRTNbOwViDipeA",
            "id" => "3koiLjNrgRTNbOwViDipeA",
            "name" => "Marvin Gaye",
            "type" => "artist",
            "uri" => "spotify:artist:3koiLjNrgRTNbOwViDipeA"
          },
          %{
            "external_urls" => %{
              "spotify" => "https://open.spotify.com/artist/75jNCko3SnEMI5gwGqrbb8"
            },
            "href" => "https://api.spotify.com/v1/artists/75jNCko3SnEMI5gwGqrbb8",
            "id" => "75jNCko3SnEMI5gwGqrbb8",
            "name" => "Tammi Terrell",
            "type" => "artist",
            "uri" => "spotify:artist:75jNCko3SnEMI5gwGqrbb8"
          }
        ],
        "available_markets" => [],
        "disc_number" => 1,
        "duration_ms" => 151_666,
        "explicit" => false,
        "external_ids" => %{"isrc" => "USMO16700534"},
        "external_urls" => %{
          "spotify" => "https://open.spotify.com/track/7tqhbajSfrz2F7E1Z75ASX"
        },
        "href" => "https://api.spotify.com/v1/tracks/7tqhbajSfrz2F7E1Z75ASX",
        "id" => "7tqhbajSfrz2F7E1Z75ASX",
        "is_local" => false,
        "name" => "Ain't No Mountain High Enough",
        "popularity" => 82,
        "preview_url" => nil,
        "track_number" => 1,
        "type" => "track",
        "uri" => "spotify:track:7tqhbajSfrz2F7E1Z75ASX"
      },
      "progress_ms" => 2166,
      "repeat_state" => "off",
      "shuffle_state" => false,
      "smart_shuffle" => false,
      "timestamp" => 1_757_015_509_109
    }

    test "add a new track to a playlist" do
      {:ok, %Playlist{} = playlist} = Playlist.create(playlist_fixture(%{tracks: []}))

      assert playlist.tracks == []

      {:ok, playlist} = Playlist.add_track_to_playlist(playlist, @payload)

      assert [
               %Playlist.Track{
                 provider: :spotify,
                 artist: "Daft Punk",
                 name: "Around the World",
                 track_id: "1pKYYY0dkg23sQQXi0Q5zN",
                 user_id: "ku296zgwbo0e3qff8cylptsjq",
                 album_id: "5uRdvUR7xCnHmUW8n64n9y",
                 duration_ms: 429_533,
                 release_date: ~D[1900-01-01]
               }
             ] = playlist.tracks
    end

    test "add two new tracks to a playlist" do
      {:ok, %Playlist{} = playlist} = Playlist.create(playlist_fixture(%{tracks: []}))

      assert playlist.tracks == []

      {:ok, playlist} = Playlist.add_track_to_playlist(playlist, @payload)
      {:ok, playlist} = Playlist.add_track_to_playlist(playlist, @payload2)

      assert [
               %Playlist.Track{
                 provider: :spotify,
                 artist: "Daft Punk",
                 name: "Around the World",
                 track_id: "1pKYYY0dkg23sQQXi0Q5zN",
                 user_id: "ku296zgwbo0e3qff8cylptsjq",
                 album_id: "5uRdvUR7xCnHmUW8n64n9y",
                 duration_ms: 429_533,
                 release_date: ~D[1900-01-01]
               },
               %Playlist.Track{
                 provider: :spotify,
                 artist: "Marvin Gaye",
                 name: "Ain't No Mountain High Enough",
                 track_id: "7tqhbajSfrz2F7E1Z75ASX",
                 album_id: "5LqviduT0g0J0ypFrFSwCE",
                 user_id: "ku296zgwbo0e3qff8cylptsjq",
                 duration_ms: 151_666,
                 release_date: ~D[1900-01-01]
               }
             ] = playlist.tracks
    end

    test "cannot add the same track twice to a playlist" do
      {:ok, %Playlist{} = playlist} = Playlist.create(playlist_fixture(%{tracks: []}))

      assert playlist.tracks == []

      {:ok, playlist} = Playlist.add_track_to_playlist(playlist, @payload)
      {:ok, playlist} = Playlist.add_track_to_playlist(playlist, @payload2)
      {:error, _changeset} = Playlist.add_track_to_playlist(playlist, @payload)
      {:error, _changeset} = Playlist.add_track_to_playlist(playlist, @payload2)

      assert [
               %Playlist.Track{
                 provider: :spotify,
                 artist: "Daft Punk",
                 name: "Around the World",
                 track_id: "1pKYYY0dkg23sQQXi0Q5zN",
                 user_id: "ku296zgwbo0e3qff8cylptsjq",
                 album_id: "5uRdvUR7xCnHmUW8n64n9y",
                 duration_ms: 429_533,
                 release_date: ~D[1900-01-01]
               },
               %Playlist.Track{
                 provider: :spotify,
                 artist: "Marvin Gaye",
                 name: "Ain't No Mountain High Enough",
                 track_id: "7tqhbajSfrz2F7E1Z75ASX",
                 album_id: "5LqviduT0g0J0ypFrFSwCE",
                 user_id: "ku296zgwbo0e3qff8cylptsjq",
                 duration_ms: 151_666,
                 release_date: ~D[1900-01-01]
               }
             ] = playlist.tracks
    end
  end

  describe "delete/1" do
    test "delete an existing playlist" do
      {:ok, %Playlist{playlist_id: playlist_id} = playlist} = Playlist.create(playlist_fixture())

      {:ok, _} = Playlist.delete(playlist)

      assert is_nil(Playlist.get_by(playlist_id: playlist_id))
      assert Playlist.Track.all(where: [playlist_id: playlist.id]) == []
    end
  end
end
