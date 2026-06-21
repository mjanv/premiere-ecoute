defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.AddTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Album
  alias PremiereEcouteWeb.Mcp.Components.Wantlist.Add

  defp authenticated_frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  setup do
    user = user_fixture()
    {:ok, album} = Album.create(album_fixture())
    {:ok, %{user: user, album: album}}
  end

  test "adds an album to the wantlist", %{user: user, album: album} do
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = Add.execute(%{type: "album", record_id: album.id}, frame)
    assert %Hermes.Server.Response{content: [%{"text" => "Added to wantlist."}]} = resp
  end

  test "returns error for invalid type", %{user: user, album: album} do
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = Add.execute(%{type: "playlist", record_id: album.id}, frame)
    assert %Hermes.Server.Response{isError: true} = resp
  end
end
