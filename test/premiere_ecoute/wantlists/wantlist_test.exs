defmodule PremiereEcoute.Wantlists.WantlistTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wantlists
  alias PremiereEcoute.Wantlists.Wantlist
  alias PremiereEcoute.Wantlists.WantlistItem

  setup do
    user = user_fixture(%{role: :viewer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, %{user: user, album: album}}
  end

  describe "get_wantlist/1" do
    test "returns nil when wantlist does not exist", %{user: user} do
      assert nil == Wantlists.get_wantlist(user.id)
    end

    test "returns wantlist with preloaded items", %{user: user, album: album} do
      {:ok, _} = Wantlists.add_item(user.id, :album, album.id)
      assert %Wantlist{items: [%WantlistItem{type: :album, album: %Album{}}]} = Wantlists.get_wantlist(user.id)
    end

    test "returns all items for the user", %{user: user, album: album} do
      {:ok, single} = Single.create_if_not_exists(single_fixture())
      {:ok, _} = Wantlists.add_item(user.id, :album, album.id)
      {:ok, _} = Wantlists.add_item(user.id, :track, single.id)
      wantlist = Wantlists.get_wantlist(user.id)
      assert length(wantlist.items) == 2
      assert MapSet.new(Enum.map(wantlist.items, & &1.type)) == MapSet.new([:album, :track])
    end
  end

  describe "get_or_create/1" do
    test "creates a wantlist on first call", %{user: user} do
      assert {:ok, wantlist} = Wantlist.get_or_create(user.id)
      assert wantlist.user_id == user.id
    end

    test "returns existing wantlist on subsequent calls", %{user: user} do
      {:ok, first} = Wantlist.get_or_create(user.id)
      {:ok, second} = Wantlist.get_or_create(user.id)
      assert first.id == second.id
    end
  end
end
