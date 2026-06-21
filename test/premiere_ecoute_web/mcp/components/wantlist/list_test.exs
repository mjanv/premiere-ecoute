defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.ListTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteWeb.Mcp.Components.Wantlist.List

  defp authenticated_frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  setup do
    user = user_fixture()
    {:ok, album} = Album.create(album_fixture())
    {:ok, single} = Single.create_if_not_exists(single_fixture())
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Artist #{System.unique_integer([:positive])}"})
    {:ok, %{user: user, album: album, single: single, artist: artist}}
  end

  test "returns empty lists when wantlist does not exist", %{user: user} do
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = List.read(%{}, frame)
    assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
    assert {:ok, %{"albums" => [], "tracks" => [], "artists" => []}} = Jason.decode(json)
  end

  test "returns albums grouped by type", %{user: user, album: album} do
    Wantlists.add_item(user.id, :album, album.id)
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = List.read(%{}, frame)
    assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
    assert {:ok, %{"albums" => [entry]}} = Jason.decode(json)
    assert entry["name"] == album.name
    assert entry["item_id"] != nil
  end

  test "returns tracks grouped by type", %{user: user, single: single} do
    Wantlists.add_item(user.id, :track, single.id)
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = List.read(%{}, frame)
    assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
    assert {:ok, %{"tracks" => [entry]}} = Jason.decode(json)
    assert entry["name"] == single.name
  end

  test "returns artists grouped by type", %{user: user, artist: artist} do
    Wantlists.add_item(user.id, :artist, artist.id)
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = List.read(%{}, frame)
    assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
    assert {:ok, %{"artists" => [entry]}} = Jason.decode(json)
    assert entry["name"] == artist.name
  end
end
