defmodule PremiereEcouteWeb.Mcp.Components.Discography.Get.AlbumTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Discography.AlbumFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Album
  alias PremiereEcouteWeb.Mcp.Components.Discography.Get.Album, as: AlbumGet

  defp decode(resp) do
    [%{"text" => json}] = resp.content
    Jason.decode!(json)
  end

  test "returns not found for unknown id" do
    assert {:reply, resp, _} = AlbumGet.execute(%{album_id: 0}, %Frame{})
    assert resp.isError == true
    assert [%{"text" => msg}] = resp.content
    assert msg =~ "not found"
  end

  test "returns full album with tracks and artists" do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "get-album-test-#{System.unique_integer([:positive])}"}}))

    assert {:reply, resp, _} = AlbumGet.execute(%{album_id: album.id}, %Frame{})
    refute resp.isError
    data = decode(resp)
    assert data["id"] == album.id
    assert data["name"] == album.name
    assert data["slug"] == album.slug
    assert data["release_date"] == to_string(album.release_date)
    assert data["total_tracks"] == album.total_tracks
    assert is_list(data["artists"])
    assert is_list(data["tracks"])
  end

  test "tracks are sorted by track_number" do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "get-album-order-#{System.unique_integer([:positive])}"}}))

    assert {:reply, resp, _} = AlbumGet.execute(%{album_id: album.id}, %Frame{})
    data = decode(resp)
    numbers = Enum.map(data["tracks"], & &1["track_number"])
    assert numbers == Enum.sort(numbers)
  end

  test "track payload includes expected fields" do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "get-album-fields-#{System.unique_integer([:positive])}"}}))

    assert {:reply, resp, _} = AlbumGet.execute(%{album_id: album.id}, %Frame{})
    data = decode(resp)
    track = List.first(data["tracks"])
    assert Map.has_key?(track, "id")
    assert Map.has_key?(track, "name")
    assert Map.has_key?(track, "track_number")
    assert Map.has_key?(track, "duration_ms")
  end

  test "artist payload includes expected fields" do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "get-album-artist-#{System.unique_integer([:positive])}"}}))

    assert {:reply, resp, _} = AlbumGet.execute(%{album_id: album.id}, %Frame{})
    data = decode(resp)
    artist = List.first(data["artists"])
    assert Map.has_key?(artist, "id")
    assert Map.has_key?(artist, "name")
    assert Map.has_key?(artist, "slug")
  end

  test "includes external_links" do
    {:ok, album} =
      Album.create(album_fixture(%{provider_ids: %{spotify: "get-album-links-#{System.unique_integer([:positive])}"}}))

    assert {:reply, resp, _} = AlbumGet.execute(%{album_id: album.id}, %Frame{})
    data = decode(resp)
    assert Map.has_key?(data, "external_links")
  end
end
