defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.RemoveTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteWeb.Mcp.Components.Wantlist.Remove

  defp authenticated_frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  setup do
    user = user_fixture()
    {:ok, album} = Album.create(album_fixture())
    {:ok, item} = Wantlists.add_item(user.id, :album, album.id)
    {:ok, %{user: user, item: item}}
  end

  test "removes an item by item_id", %{user: user, item: item} do
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = Remove.execute(%{item_id: item.id}, frame)
    assert %Hermes.Server.Response{content: [%{"text" => "Removed from wantlist."}]} = resp
  end

  test "returns error when item not found", %{user: user} do
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = Remove.execute(%{item_id: 999_999}, frame)
    assert %Hermes.Server.Response{isError: true} = resp
  end

  test "cannot remove another user's item", %{item: item} do
    other_user = user_fixture()
    frame = authenticated_frame(other_user)

    assert {:reply, resp, ^frame} = Remove.execute(%{item_id: item.id}, frame)
    assert %Hermes.Server.Response{isError: true} = resp
  end
end
