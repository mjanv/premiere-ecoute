defmodule PremiereEcoute.Discography.AlbumTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Events.AlbumAdded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  describe "create/1" do
    test "creates an album with tracks" do
      {:ok, album} = Discography.create_album(album_fixture())

      assert %Album{
               provider_ids: %{spotify: "album123"},
               name: "Sample Album",
               slug: "sample-album",
               artist: %Artist{name: "Sample Artist"},
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   provider_ids: %{spotify: "track001"},
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   provider_ids: %{spotify: "track002"},
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end

    test "does not recreate an existing album" do
      {:ok, _} = Album.create(album_fixture())
      {:error, changeset} = Album.create(album_fixture())

      assert Repo.traverse_errors(changeset) != %{}
    end

    test "appends AlbumAdded event" do
      {:ok, album} = Discography.create_album(album_fixture())

      artist_name = album.artists |> List.first() |> then(&(&1 && &1.name))
      assert Store.last("album-#{album.id}") == %AlbumAdded{id: album.id, name: album.name, artist: artist_name}
    end
  end

  describe "create_if_not_exists/1" do
    test "create an unexisting album with tracks" do
      {:ok, album} = Album.create_if_not_exists(album_fixture())

      assert %Album{
               provider_ids: %{spotify: "album123"},
               name: "Sample Album",
               artist: %Artist{name: "Sample Artist"},
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   provider_ids: %{spotify: "track001"},
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   provider_ids: %{spotify: "track002"},
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end

    test "does not recreate an existing album" do
      {:ok, _} = Album.create_if_not_exists(album_fixture())
      {:ok, album} = Album.create_if_not_exists(album_fixture())

      assert %Album{
               provider_ids: %{spotify: "album123"},
               name: "Sample Album",
               artist: %Artist{name: "Sample Artist"},
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   provider_ids: %{spotify: "track001"},
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   provider_ids: %{spotify: "track002"},
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end
  end

  describe "get/1" do
    test "get an existing album" do
      {:ok, %Album{id: id}} = Album.create(album_fixture())

      album = Album.get(id)

      assert %Album{
               provider_ids: %{spotify: "album123"},
               name: "Sample Album",
               artist: %Artist{name: "Sample Artist"},
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   provider_ids: %{spotify: "track001"},
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   provider_ids: %{spotify: "track002"},
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end

    test "get an unexisting album" do
      assert is_nil(Album.get(-1))
    end
  end

  describe "get_by/1" do
    test "get an existing album" do
      user = user_fixture()
      {:ok, %Album{} = album} = Album.create(album_fixture())
      {:ok, _} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      found = Album.get_by(slug: album.slug)

      assert %Album{
               provider_ids: %{spotify: "album123"},
               name: "Sample Album",
               artist: %Artist{name: "Sample Artist"}
             } = found
    end

    test "get an unexisting album" do
      assert is_nil(Album.get_by(slug: "unknown-slug"))
    end
  end

  describe "track external_links" do
    test "stores external links on a track" do
      {:ok, album} =
        Album.create(
          album_fixture(%{
            tracks: [
              %Track{
                provider_ids: %{spotify: "track001"},
                name: "Track One",
                track_number: 1,
                duration_ms: 210_000,
                external_links: %{"genius" => "https://genius.com/Daft-punk-one-more-time-lyrics"}
              }
            ],
            total_tracks: 1
          })
        )

      assert [%Track{external_links: %{"genius" => "https://genius.com/Daft-punk-one-more-time-lyrics"}}] = album.tracks
    end

    test "rejects invalid URLs on a track" do
      changeset =
        Track.changeset(%Track{}, %{
          provider_ids: %{spotify: "track001"},
          name: "Track One",
          track_number: 1,
          duration_ms: 210_000,
          external_links: %{"genius" => "not-a-url"}
        })

      assert %{external_links: ["contains invalid URL: not-a-url"]} = Repo.traverse_errors(changeset)
    end
  end

  describe "external_links" do
    test "stores external links" do
      {:ok, album} =
        Album.create(album_fixture(%{external_links: %{"wikipedia" => "https://en.wikipedia.org/wiki/Random_Access_Memories"}}))

      assert album.external_links == %{"wikipedia" => "https://en.wikipedia.org/wiki/Random_Access_Memories"}
    end

    test "stores multiple external links" do
      {:ok, album} =
        Album.create(
          album_fixture(%{
            external_links: %{
              "wikipedia" => "https://en.wikipedia.org/wiki/Random_Access_Memories",
              "genius" => "https://genius.com/albums/Daft-punk/Random-access-memories"
            }
          })
        )

      assert album.external_links == %{
               "wikipedia" => "https://en.wikipedia.org/wiki/Random_Access_Memories",
               "genius" => "https://genius.com/albums/Daft-punk/Random-access-memories"
             }
    end

    test "defaults to empty map" do
      {:ok, album} = Album.create(album_fixture())

      assert album.external_links == %{}
    end

    test "rejects invalid URLs" do
      {:error, changeset} = Album.create(album_fixture(%{external_links: %{"wikipedia" => "not-a-url"}}))

      assert %{external_links: ["contains invalid URL: not-a-url"]} = Repo.traverse_errors(changeset)
    end
  end

  describe "delete/1" do
    test "delete an existing album" do
      {:ok, %Album{} = album} = Album.create(album_fixture())

      {:ok, _} = Album.delete(album)

      assert is_nil(Album.get(album.id))
    end

    test "can delete stale album" do
      {:ok, %Album{} = album} = Album.create(album_fixture())

      {:ok, _} = Album.delete(album)
      {:ok, _} = Album.delete(album)

      assert is_nil(Album.get(album.id))
    end

    test "cannot delete an album associated to at least one listening session" do
      user = user_fixture()
      {:ok, %Album{} = album} = Album.create(album_fixture())
      {:ok, _} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})

      {:error, changeset} = Album.delete(album)

      assert Repo.traverse_errors(changeset) == %{listening_sessions: ["are still linked to this album"]}

      assert !is_nil(Album.get(album.id))
    end
  end
end
