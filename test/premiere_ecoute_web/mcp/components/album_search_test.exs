defmodule PremiereEcouteWeb.Mcp.Components.AlbumSearchTest do
  use PremiereEcoute.DataCase

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Album
  alias PremiereEcouteWeb.Mcp.Components.AlbumSearch

  test "album search returns matching album" do
    # Create test album
    album = album_fixture(%{name: "Test Album", release_date: ~D[2023-06-15], total_tracks: 12})
    {:ok, _} = Album.create(album)

    frame = %Frame{}

    # Search for the album
    assert {:reply, resp, ^frame} = AlbumSearch.execute(%{name: "Test Album"}, frame)
    assert %Hermes.Server.Response{type: :tool, content: [%{"text" => json_str, "type" => "text"}]} = resp
    assert {:ok, %{"albums" => albums}} = Jason.decode(json_str)
    assert [album_data] = albums
    assert album_data["name"] == "Test Album"
    assert album_data["total_tracks"] == 12
    assert album_data["release_date"] == "2023-06-15"
  end

  test "album search returns empty list when no matches" do
    frame = %Frame{}

    # Search for non-existent album
    assert {:reply, resp, ^frame} = AlbumSearch.execute(%{name: "Nonexistent Album"}, frame)
    assert %Hermes.Server.Response{type: :tool, content: [%{"text" => json_str, "type" => "text"}]} = resp
    assert {:ok, %{"albums" => albums}} = Jason.decode(json_str)
    assert albums == []
  end

  test "album search returns album by exact name match" do
    # Create album with specific name
    album =
      album_fixture(%{
        name: "Kind Of Blue",
        release_date: ~D[1959-08-17],
        total_tracks: 5,
        provider_ids: %{spotify: "kind_of_blue_1959"}
      })

    {:ok, _} = Album.create(album)

    frame = %Frame{}

    # Search for the album with exact name
    assert {:reply, resp, ^frame} = AlbumSearch.execute(%{name: "Kind Of Blue"}, frame)
    assert %Hermes.Server.Response{type: :tool, content: [%{"text" => json_str, "type" => "text"}]} = resp
    assert {:ok, %{"albums" => albums}} = Jason.decode(json_str)
    assert [album_data] = albums
    assert album_data["name"] == "Kind Of Blue"
    assert album_data["total_tracks"] == 5
  end

  test "album search response includes only required fields" do
    album = album_fixture(%{name: "My Album"})
    {:ok, _} = Album.create(album)

    frame = %Frame{}

    assert {:reply, resp, ^frame} = AlbumSearch.execute(%{name: "My Album"}, frame)
    assert %Hermes.Server.Response{type: :tool, content: [%{"text" => json_str, "type" => "text"}]} = resp
    assert {:ok, %{"albums" => [album_data]}} = Jason.decode(json_str)

    # Verify only expected fields are present
    assert Map.has_key?(album_data, "name")
    assert Map.has_key?(album_data, "release_date")
    assert Map.has_key?(album_data, "total_tracks")

    # Verify no extra fields are included
    assert map_size(album_data) == 3
  end
end
