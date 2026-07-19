defmodule PremiereEcoute.Sessions.AlbumPicksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Sessions.AlbumPick
  alias PremiereEcoute.Sessions.AlbumPicks

  defp pick_attrs(overrides \\ %{}) do
    Map.merge(
      %{album_id: "album-#{System.unique_integer([:positive])}", name: "Some Album", artist: "Some Artist"},
      overrides
    )
  end

  describe "add_entry/2" do
    test "creates a new pick" do
      user = user_fixture()

      assert {:ok, pick} = AlbumPicks.add_entry(user.id, pick_attrs())
      assert pick.user_id == user.id
      assert pick.source == :streamer
    end

    test "returns the existing pick when the same album is added twice (duplicate-add race)" do
      user = user_fixture()
      attrs = pick_attrs(%{album_id: "dup-album"})

      {:ok, first} = AlbumPicks.add_entry(user.id, attrs)

      # Simulates the race this handling exists for: a second insert attempt for the same
      # (user_id, album_id) pair hits the DB's unique constraint instead of an application-level
      # pre-check, since two concurrent requests can both pass a naive "does it exist" check.
      assert {:ok, second} = AlbumPicks.add_entry(user.id, attrs)
      assert second.id == first.id
    end

    test "a validation failure takes precedence over the unique constraint (never reaches the DB)" do
      # Ecto's constraint checks (like unique_constraint/3) are deferred to the database and
      # only run if the changeset is otherwise valid — Repo.insert short-circuits before that
      # on a validation failure. So a duplicate submitted with an additional invalid attribute
      # surfaces the validation error, not :already_exists, and no duplicate row is at risk.
      user = user_fixture()
      attrs = pick_attrs(%{album_id: "dup-with-other-error"})

      {:ok, _first} = AlbumPicks.add_entry(user.id, attrs)

      too_long_artist = String.duplicate("x", 300)
      assert {:error, changeset} = AlbumPicks.add_entry(user.id, Map.put(attrs, :artist, too_long_artist))
      assert %{artist: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "different users can pick the same album" do
      user1 = user_fixture()
      user2 = user_fixture()
      attrs = pick_attrs(%{album_id: "shared-album"})

      assert {:ok, pick1} = AlbumPicks.add_entry(user1.id, attrs)
      assert {:ok, pick2} = AlbumPicks.add_entry(user2.id, attrs)
      assert pick1.id != pick2.id
    end

    test "returns a changeset error for invalid attrs unrelated to the unique constraint" do
      user = user_fixture()

      assert {:error, changeset} = AlbumPicks.add_entry(user.id, pick_attrs(%{name: nil}))
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "add_viewer_entry/3" do
    test "creates a new viewer-submitted pick" do
      user = user_fixture()

      assert {:ok, pick} = AlbumPicks.add_viewer_entry(user.id, pick_attrs(), "viewer123")
      assert pick.source == :viewer
      assert pick.submitter == "viewer123"
    end

    test "rejects a duplicate viewer submission instead of returning the existing pick" do
      user = user_fixture()
      attrs = pick_attrs(%{album_id: "dup-viewer-album"})

      {:ok, _first} = AlbumPicks.add_viewer_entry(user.id, attrs, "viewer1")

      assert {:error, :already_exists} = AlbumPicks.add_viewer_entry(user.id, attrs, "viewer2")
    end

    test "rejects a duplicate even against a streamer-added pick for the same album" do
      user = user_fixture()
      attrs = pick_attrs(%{album_id: "dup-cross-source"})

      {:ok, _} = AlbumPicks.add_entry(user.id, attrs)

      assert {:error, :already_exists} = AlbumPicks.add_viewer_entry(user.id, attrs, "viewer1")
    end
  end

  describe "list_for_user/1" do
    test "returns picks ordered by most recently added" do
      user = user_fixture()

      {:ok, first} = AlbumPicks.add_entry(user.id, pick_attrs())

      first =
        first
        |> Ecto.Changeset.change(inserted_at: DateTime.add(first.inserted_at, -60, :second))
        |> PremiereEcoute.Repo.update!()

      {:ok, second} = AlbumPicks.add_entry(user.id, pick_attrs())

      assert [^second, ^first] = AlbumPicks.list_for_user(user.id)
    end

    test "does not return picks belonging to another user" do
      user = user_fixture()
      other = user_fixture()

      {:ok, _} = AlbumPicks.add_entry(other.id, pick_attrs())

      assert AlbumPicks.list_for_user(user.id) == []
    end
  end

  describe "remove_entry/2" do
    test "removes a pick owned by the user" do
      user = user_fixture()
      {:ok, pick} = AlbumPicks.add_entry(user.id, pick_attrs())

      assert {:ok, removed} = AlbumPicks.remove_entry(user.id, pick.id)
      assert removed.id == pick.id
      assert AlbumPicks.list_for_user(user.id) == []
    end

    test "returns :not_found when the pick belongs to another user" do
      user = user_fixture()
      other = user_fixture()
      {:ok, pick} = AlbumPicks.add_entry(other.id, pick_attrs())

      assert {:error, :not_found} = AlbumPicks.remove_entry(user.id, pick.id)
      assert AlbumPick |> PremiereEcoute.Repo.get(pick.id)
    end

    test "returns :not_found for a nonexistent id" do
      user = user_fixture()

      assert {:error, :not_found} = AlbumPicks.remove_entry(user.id, -1)
    end
  end

  describe "count_for_user/1" do
    test "counts the user's picks" do
      user = user_fixture()
      {:ok, _} = AlbumPicks.add_entry(user.id, pick_attrs())
      {:ok, _} = AlbumPicks.add_entry(user.id, pick_attrs())

      assert AlbumPicks.count_for_user(user.id) == 2
    end

    test "returns 0 for a user with no picks" do
      user = user_fixture()

      assert AlbumPicks.count_for_user(user.id) == 0
    end
  end

  describe "clear_all/1" do
    test "removes all picks for the user and returns the deleted count" do
      user = user_fixture()
      {:ok, _} = AlbumPicks.add_entry(user.id, pick_attrs())
      {:ok, _} = AlbumPicks.add_entry(user.id, pick_attrs())

      assert AlbumPicks.clear_all(user.id) == 2
      assert AlbumPicks.list_for_user(user.id) == []
    end

    test "does not remove another user's picks" do
      user = user_fixture()
      other = user_fixture()
      {:ok, _} = AlbumPicks.add_entry(other.id, pick_attrs())

      assert AlbumPicks.clear_all(user.id) == 0
      assert AlbumPicks.count_for_user(other.id) == 1
    end
  end

  describe "random_entry/1" do
    test "returns one of the user's picks" do
      user = user_fixture()
      {:ok, pick} = AlbumPicks.add_entry(user.id, pick_attrs())

      assert AlbumPicks.random_entry(user.id).id == pick.id
    end

    test "returns nil when the user has no picks" do
      user = user_fixture()

      assert AlbumPicks.random_entry(user.id) == nil
    end
  end
end
