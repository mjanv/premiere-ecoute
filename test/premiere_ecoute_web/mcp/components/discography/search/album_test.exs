defmodule PremiereEcouteWeb.Mcp.Components.Discography.Search.AlbumTest do
  use PremiereEcoute.DataCase, async: true

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.AlbumArtist
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcouteWeb.Mcp.Components.Discography.Search.Album, as: AlbumSearch

  test "finds album by partial name match" do
    album = album_fixture(%{name: "Kind Of Blue", release_date: ~D[1959-08-17], total_tracks: 5})
    {:ok, _} = Album.create(album)

    assert {:reply, resp, _} = AlbumSearch.execute(%{name: "Kind"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"albums" => [entry]}} = Jason.decode(json)
    assert entry["name"] == "Kind Of Blue"
  end

  test "finds album by partial artist name" do
    album = album_fixture(%{name: "Unique Album XYZ"})
    {:ok, album} = Album.create(album)
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Fuzzy Artist Unique"})
    Repo.insert!(%AlbumArtist{album_id: album.id, artist_id: artist.id})

    assert {:reply, resp, _} = AlbumSearch.execute(%{name: "Fuzzy Artist"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"albums" => albums}} = Jason.decode(json)
    assert Enum.any?(albums, &(&1["name"] == "Unique Album XYZ"))
  end

  test "search is case-insensitive" do
    album = album_fixture(%{name: "Dark Side Of The Moon"})
    {:ok, _} = Album.create(album)

    assert {:reply, resp, _} = AlbumSearch.execute(%{name: "dark side"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"albums" => [entry]}} = Jason.decode(json)
    assert entry["name"] == "Dark Side Of The Moon"
  end

  test "returns empty list when no matches" do
    assert {:reply, resp, _} = AlbumSearch.execute(%{name: "zzznomatch"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"albums" => []}} = Jason.decode(json)
  end

  test "finds all albums for a given artist_id" do
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Artist For ID Search"})
    album = album_fixture(%{name: "Artist ID Album"})
    {:ok, album} = Album.create(album)
    Repo.insert!(%AlbumArtist{album_id: album.id, artist_id: artist.id})

    assert {:reply, resp, _} = AlbumSearch.execute(%{artist_id: artist.id}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"albums" => [entry]}} = Jason.decode(json)
    assert entry["name"] == "Artist ID Album"
  end

  test "returns error when neither name nor artist_id provided" do
    assert {:reply, resp, _} = AlbumSearch.execute(%{}, %Frame{})
    assert %Hermes.Server.Response{isError: true} = resp
  end

  test "response includes id, name, release_date, total_tracks, artist" do
    album = album_fixture(%{name: "Fields Check Album"})
    {:ok, _} = Album.create(album)

    assert {:reply, resp, _} = AlbumSearch.execute(%{name: "Fields Check Album"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"albums" => [entry]}} = Jason.decode(json)

    assert Map.has_key?(entry, "id")
    assert Map.has_key?(entry, "name")
    assert Map.has_key?(entry, "release_date")
    assert Map.has_key?(entry, "total_tracks")
    assert Map.has_key?(entry, "artist")
  end
end
