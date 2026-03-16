defmodule PremiereEcoute.Discography.ArtistTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Artist.Image

  defp artist_fixture(attrs \\ %{}) do
    struct(
      Artist,
      Map.merge(
        %{
          name: "Sample Artist",
          provider_ids: %{spotify: "artist123"},
          images: [
            %Image{url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228", height: 300, width: 300}
          ]
        },
        attrs
      )
    )
  end

  describe "create/1" do
    test "creates an artist with provider_ids and images" do
      {:ok, artist} = Artist.create(artist_fixture())

      assert %Artist{
               name: "Sample Artist",
               slug: "sample-artist",
               provider_ids: %{spotify: "artist123"},
               images: [%Image{url: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228", height: 300, width: 300}]
             } = artist
    end

    test "does not recreate an existing artist" do
      {:ok, _} = Artist.create(artist_fixture())
      {:error, changeset} = Artist.create(artist_fixture())

      assert Repo.traverse_errors(changeset) != %{}
    end
  end

  describe "create_if_not_exists/1" do
    test "creates an artist when it does not exist" do
      {:ok, artist} = Artist.create_if_not_exists(artist_fixture())

      assert %Artist{name: "Sample Artist", provider_ids: %{spotify: "artist123"}} = artist
    end

    test "returns existing artist when it already exists" do
      {:ok, %Artist{id: id}} = Artist.create_if_not_exists(artist_fixture())
      {:ok, artist} = Artist.create_if_not_exists(artist_fixture())

      assert artist.id == id
    end
  end

  describe "get/1" do
    test "returns an existing artist" do
      {:ok, %Artist{id: id}} = Artist.create(artist_fixture())

      assert %Artist{name: "Sample Artist"} = Artist.get(id)
    end

    test "returns nil for unknown id" do
      assert is_nil(Artist.get(-1))
    end
  end

  describe "get_by_slug/1" do
    test "returns an existing artist by slug" do
      {:ok, _} = Artist.create(artist_fixture())

      assert %Artist{name: "Sample Artist", slug: "sample-artist"} = Artist.get_by_slug("sample-artist")
    end

    test "returns nil for unknown slug" do
      assert is_nil(Artist.get_by_slug("unknown-artist"))
    end
  end

  describe "images" do
    test "stores multiple images" do
      attrs =
        artist_fixture(%{
          images: [
            %Image{url: "https://example.com/large.jpg", height: 640, width: 640},
            %Image{url: "https://example.com/medium.jpg", height: 300, width: 300},
            %Image{url: "https://example.com/small.jpg", height: 64, width: 64}
          ]
        })

      {:ok, artist} = Artist.create(attrs)

      assert [
               %Image{height: 640, width: 640},
               %Image{height: 300, width: 300},
               %Image{height: 64, width: 64}
             ] = artist.images
    end

    test "stores an artist with no images" do
      {:ok, artist} = Artist.create(artist_fixture(%{images: []}))

      assert artist.images == []
    end
  end

  describe "delete/1" do
    test "deletes an existing artist" do
      {:ok, %Artist{} = artist} = Artist.create(artist_fixture())

      {:ok, _} = Artist.delete(artist)

      assert is_nil(Artist.get(artist.id))
    end
  end
end
