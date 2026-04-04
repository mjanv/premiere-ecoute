defmodule PremiereEcoute.Wantlists.WantlistItemTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Events.AddedToWantlist
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Wantlists
  alias PremiereEcoute.Wantlists.Wantlist

  setup do
    user = user_fixture(%{role: :viewer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, single} = Single.create_if_not_exists(single_fixture())
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Test Artist #{System.unique_integer([:positive])}"})
    {:ok, %{user: user, album: album, single: single, artist: artist}}
  end

  describe "add/3" do
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

    test "appends AddedToWantlist event on album add", %{user: user, album: album} do
      {:ok, _} = Wantlists.add_item(user.id, :album, album.id)
      assert Store.last("wantlist-#{user.id}") == %AddedToWantlist{id: user.id, type: "album", record_id: album.id}
    end

    test "appends AddedToWantlist event on track add", %{user: user, single: single} do
      {:ok, _} = Wantlists.add_item(user.id, :track, single.id)
      assert Store.last("wantlist-#{user.id}") == %AddedToWantlist{id: user.id, type: "track", record_id: single.id}
    end

    test "appends AddedToWantlist event on artist add", %{user: user, artist: artist} do
      {:ok, _} = Wantlists.add_item(user.id, :artist, artist.id)
      assert Store.last("wantlist-#{user.id}") == %AddedToWantlist{id: user.id, type: "artist", record_id: artist.id}
    end
  end

  describe "remove/2 (by item id)" do
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

  describe "remove/3 (by type and record id)" do
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

  describe "exists?/3" do
    test "returns false when wantlist does not exist", %{user: user, album: album} do
      refute Wantlists.in_wantlist?(user.id, :album, album.id)
    end

    test "returns false when item is not in wantlist", %{user: user, album: album} do
      Wantlist.get_or_create(user.id)
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

  describe "wantlisted_spotify_ids/2" do
    test "returns empty MapSet for empty list", %{user: user} do
      assert MapSet.new() == Wantlists.wantlisted_spotify_ids(user.id, [])
    end

    test "returns spotify id of a wantlisted single", %{user: user, single: single} do
      Wantlists.add_item(user.id, :track, single.id)
      spotify_id = single.provider_ids[:spotify]
      assert MapSet.member?(Wantlists.wantlisted_spotify_ids(user.id, [spotify_id]), spotify_id)
    end

    test "returns spotify ids of all tracks of a wantlisted album", %{user: user, album: album} do
      Wantlists.add_item(user.id, :album, album.id)
      track_spotify_ids = Enum.map(album.tracks, & &1.provider_ids[:spotify])
      result = Wantlists.wantlisted_spotify_ids(user.id, track_spotify_ids)
      assert MapSet.equal?(result, MapSet.new(track_spotify_ids))
    end

    test "does not return ids not in wantlist", %{user: user} do
      refute MapSet.member?(Wantlists.wantlisted_spotify_ids(user.id, ["unknown_id"]), "unknown_id")
    end

    test "does not return ids from another user's wantlist", %{user: user, single: single} do
      other_user = user_fixture(%{role: :viewer})
      Wantlists.add_item(other_user.id, :track, single.id)
      spotify_id = single.provider_ids[:spotify]
      refute MapSet.member?(Wantlists.wantlisted_spotify_ids(user.id, [spotify_id]), spotify_id)
    end
  end
end
