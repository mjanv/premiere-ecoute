defmodule PremiereEcoute.WantlistsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wantlists
  alias PremiereEcoute.Wantlists.Wantlist
  alias PremiereEcoute.Wantlists.WantlistItem

  setup do
    user = user_fixture(%{role: :viewer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, single} = Single.create_if_not_exists(single_fixture())
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Test Artist #{System.unique_integer([:positive])}"})
    {:ok, %{user: user, album: album, single: single, artist: artist}}
  end

  describe "get_or_create_default/1" do
    test "creates a default wantlist on first call", %{user: user} do
      assert {:ok, wantlist} = Wantlists.get_or_create_default(user.id)
      assert wantlist.user_id == user.id
    end

    test "returns existing wantlist on subsequent calls", %{user: user} do
      {:ok, first} = Wantlists.get_or_create_default(user.id)
      {:ok, second} = Wantlists.get_or_create_default(user.id)
      assert first.id == second.id
    end
  end

  describe "get_wantlist/1" do
    test "returns nil when wantlist does not exist", %{user: user} do
      assert nil == Wantlists.get_wantlist(user.id)
    end

    test "returns wantlist with preloaded items", %{user: user, album: album} do
      {:ok, _} = Wantlists.add_item(user.id, :album, album.id)
      assert %Wantlist{items: [%WantlistItem{type: :album, album: %Album{}}]} = Wantlists.get_wantlist(user.id)
    end

    test "returns all items for the user", %{user: user, album: album, single: single} do
      {:ok, _} = Wantlists.add_item(user.id, :album, album.id)
      {:ok, _} = Wantlists.add_item(user.id, :track, single.id)
      wantlist = Wantlists.get_wantlist(user.id)
      assert length(wantlist.items) == 2
      types = Enum.map(wantlist.items, & &1.type) |> MapSet.new()
      assert types == MapSet.new([:album, :track])
    end
  end

  describe "add_item/3" do
    test "adds an album to the wantlist", %{user: user, album: album} do
      assert {:ok, item} = Wantlists.add_item(user.id, :album, album.id)
      assert item.type == :album
      assert item.album_id == album.id
    end

    test "adds a single to the wantlist", %{user: user, single: single} do
      assert {:ok, item} = Wantlists.add_item(user.id, :track, single.id)
      assert item.type == :track
      assert item.single_id == single.id
    end

    test "adds an artist to the wantlist", %{user: user, artist: artist} do
      assert {:ok, item} = Wantlists.add_item(user.id, :artist, artist.id)
      assert item.type == :artist
      assert item.artist_id == artist.id
    end

    test "silently returns existing item when already in wantlist", %{user: user, album: album} do
      {:ok, first} = Wantlists.add_item(user.id, :album, album.id)
      {:ok, second} = Wantlists.add_item(user.id, :album, album.id)
      assert first.id == second.id
    end

    test "returns error when record does not exist", %{user: user} do
      assert {:error, _changeset} = Wantlists.add_item(user.id, :album, 999_999)
    end
  end

  describe "remove_item/2" do
    test "removes an existing item from the wantlist", %{user: user, album: album} do
      {:ok, item} = Wantlists.add_item(user.id, :album, album.id)
      assert {:ok, _} = Wantlists.remove_item(user.id, item.id)
      assert %Wantlist{items: []} = Wantlists.get_wantlist(user.id)
    end

    test "returns not_found when item does not exist", %{user: user} do
      assert {:error, :not_found} = Wantlists.remove_item(user.id, 999_999)
    end

    test "returns not_found when item belongs to another user", %{user: user, album: album} do
      other_user = user_fixture(%{role: :viewer})
      {:ok, item} = Wantlists.add_item(user.id, :album, album.id)
      assert {:error, :not_found} = Wantlists.remove_item(other_user.id, item.id)
    end
  end

  describe "remove_item/3" do
    test "removes an album by type and record id", %{user: user, album: album} do
      Wantlists.add_item(user.id, :album, album.id)
      assert {:ok, _} = Wantlists.remove_item(user.id, :album, album.id)
      assert %Wantlist{items: []} = Wantlists.get_wantlist(user.id)
    end

    test "removes a single by type and record id", %{user: user, single: single} do
      Wantlists.add_item(user.id, :track, single.id)
      assert {:ok, _} = Wantlists.remove_item(user.id, :track, single.id)
      assert %Wantlist{items: []} = Wantlists.get_wantlist(user.id)
    end

    test "removes an artist by type and record id", %{user: user, artist: artist} do
      Wantlists.add_item(user.id, :artist, artist.id)
      assert {:ok, _} = Wantlists.remove_item(user.id, :artist, artist.id)
      assert %Wantlist{items: []} = Wantlists.get_wantlist(user.id)
    end

    test "returns not_found when record is not in wantlist", %{user: user, album: album} do
      assert {:error, :not_found} = Wantlists.remove_item(user.id, :album, album.id)
    end

    test "returns not_found when record belongs to another user", %{user: user, album: album} do
      other_user = user_fixture(%{role: :viewer})
      Wantlists.add_item(user.id, :album, album.id)
      assert {:error, :not_found} = Wantlists.remove_item(other_user.id, :album, album.id)
    end
  end

  describe "in_wantlist?/3" do
    test "returns false when wantlist does not exist", %{user: user, album: album} do
      refute Wantlists.in_wantlist?(user.id, :album, album.id)
    end

    test "returns false when item is not in wantlist", %{user: user, album: album} do
      Wantlists.get_or_create_default(user.id)
      refute Wantlists.in_wantlist?(user.id, :album, album.id)
    end

    test "returns true when album is in wantlist", %{user: user, album: album} do
      Wantlists.add_item(user.id, :album, album.id)
      assert Wantlists.in_wantlist?(user.id, :album, album.id)
    end

    test "returns true when single is in wantlist", %{user: user, single: single} do
      Wantlists.add_item(user.id, :track, single.id)
      assert Wantlists.in_wantlist?(user.id, :track, single.id)
    end

    test "returns true when artist is in wantlist", %{user: user, artist: artist} do
      Wantlists.add_item(user.id, :artist, artist.id)
      assert Wantlists.in_wantlist?(user.id, :artist, artist.id)
    end
  end

  describe "add_radio_track/2" do
    test "adds the matching single to the wantlist", %{user: user, single: single} do
      spotify_id = single.provider_ids[:spotify]
      assert {:ok, item} = Wantlists.add_radio_track(user.id, spotify_id)
      assert item.type == :track
      assert item.single_id == single.id
    end

    test "returns not_found when no single has that Spotify ID", %{user: user} do
      assert {:error, :not_found} = Wantlists.add_radio_track(user.id, "nonexistent_id")
    end
  end
end
