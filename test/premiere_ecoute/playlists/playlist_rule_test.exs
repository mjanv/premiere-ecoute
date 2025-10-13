defmodule PremiereEcoute.Playlists.PlaylistRuleTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.PlaylistRule

  describe "changeset/2" do
    test "valid changeset with required fields" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      attrs = %{
        rule_type: :save_tracks,
        active: true,
        user_id: user.id,
        library_playlist_id: library_playlist.id
      }

      changeset = PlaylistRule.changeset(%PlaylistRule{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :rule_type) == :save_tracks
      assert get_field(changeset, :active) == true
      assert changeset.changes.user_id == user.id
      assert changeset.changes.library_playlist_id == library_playlist.id
    end

    test "defaults rule_type to save_tracks" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      attrs = %{
        user_id: user.id,
        library_playlist_id: library_playlist.id
      }

      changeset = PlaylistRule.changeset(%PlaylistRule{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :rule_type) == :save_tracks
    end

    test "requires user_id" do
      library_playlist = library_playlist_fixture(user_fixture())

      attrs = %{
        rule_type: :save_tracks,
        library_playlist_id: library_playlist.id
      }

      changeset = PlaylistRule.changeset(%PlaylistRule{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires library_playlist_id" do
      user = user_fixture()

      attrs = %{
        rule_type: :save_tracks,
        user_id: user.id
      }

      changeset = PlaylistRule.changeset(%PlaylistRule{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).library_playlist_id
    end

    test "validates rule_type is in allowed values" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      attrs = %{
        rule_type: :invalid_type,
        user_id: user.id,
        library_playlist_id: library_playlist.id
      }

      changeset = PlaylistRule.changeset(%PlaylistRule{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).rule_type
    end
  end

  describe "set_save_tracks_playlist/2" do
    test "creates active rule for user with no existing rules" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      assert {:ok, rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      assert rule.rule_type == :save_tracks
      assert rule.active == true
      assert rule.user_id == user.id
      assert rule.library_playlist_id == library_playlist.id
    end

    test "deactivates existing rule and creates new active rule" do
      user = user_fixture()
      old_playlist = library_playlist_fixture(user)
      new_playlist = library_playlist_fixture(user, %{title: "New Playlist"})

      # Create initial rule
      {:ok, old_rule} = PlaylistRule.set_save_tracks_playlist(user, old_playlist)
      assert old_rule.active == true

      # Set new rule
      assert {:ok, new_rule} = PlaylistRule.set_save_tracks_playlist(user, new_playlist)

      # Verify old rule is deactivated
      old_rule_reloaded = Repo.get!(PlaylistRule, old_rule.id)
      assert old_rule_reloaded.active == false

      # Verify new rule is active
      assert new_rule.active == true
      assert new_rule.library_playlist_id == new_playlist.id
    end

    test "only one active rule per user per rule_type" do
      user = user_fixture()
      playlist1 = library_playlist_fixture(user)
      playlist2 = library_playlist_fixture(user, %{title: "Playlist 2"})

      # Create two rules
      {:ok, _rule1} = PlaylistRule.set_save_tracks_playlist(user, playlist1)
      {:ok, _rule2} = PlaylistRule.set_save_tracks_playlist(user, playlist2)

      # Only one should be active
      active_rules =
        from(pr in PlaylistRule,
          where: pr.user_id == ^user.id and pr.rule_type == :save_tracks and pr.active == true
        )
        |> Repo.all()

      assert length(active_rules) == 1
      assert hd(active_rules).library_playlist_id == playlist2.id
    end
  end

  describe "get_save_tracks_playlist/1" do
    test "returns library playlist when active rule exists" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      result = PlaylistRule.get_save_tracks_playlist(user)

      assert %LibraryPlaylist{} = result
      assert result.id == library_playlist.id
      assert result.title == library_playlist.title
    end

    test "returns nil when no active rule exists" do
      user = user_fixture()

      result = PlaylistRule.get_save_tracks_playlist(user)

      assert result == nil
    end

    test "returns nil when only inactive rules exist" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)
      PlaylistRule.deactivate_save_tracks_playlist(user)

      result = PlaylistRule.get_save_tracks_playlist(user)

      assert result == nil
    end
  end

  describe "get_save_tracks_rule/1" do
    test "returns rule with preloaded library_playlist when active rule exists" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      {:ok, _rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)

      result = PlaylistRule.get_save_tracks_rule(user)

      assert %PlaylistRule{} = result
      assert result.active == true
      assert result.rule_type == :save_tracks
      assert result.library_playlist.id == library_playlist.id
      assert result.library_playlist.title == library_playlist.title
    end

    test "returns nil when no active rule exists" do
      user = user_fixture()

      result = PlaylistRule.get_save_tracks_rule(user)

      assert result == nil
    end
  end

  describe "deactivate_save_tracks_playlist/1" do
    test "deactivates active rule" do
      user = user_fixture()
      library_playlist = library_playlist_fixture(user)

      {:ok, rule} = PlaylistRule.set_save_tracks_playlist(user, library_playlist)
      assert rule.active == true

      {count, nil} = PlaylistRule.deactivate_save_tracks_playlist(user)
      assert count == 1

      rule_reloaded = Repo.get!(PlaylistRule, rule.id)
      assert rule_reloaded.active == false
    end

    test "returns 0 when no active rules exist" do
      user = user_fixture()

      {count, nil} = PlaylistRule.deactivate_save_tracks_playlist(user)
      assert count == 0
    end

    test "only affects the specific user's rules" do
      user1 = user_fixture()
      user2 = user_fixture()
      playlist1 = library_playlist_fixture(user1)
      playlist2 = library_playlist_fixture(user2)

      {:ok, rule1} = PlaylistRule.set_save_tracks_playlist(user1, playlist1)
      {:ok, rule2} = PlaylistRule.set_save_tracks_playlist(user2, playlist2)

      PlaylistRule.deactivate_save_tracks_playlist(user1)

      rule1_reloaded = Repo.get!(PlaylistRule, rule1.id)
      rule2_reloaded = Repo.get!(PlaylistRule, rule2.id)

      assert rule1_reloaded.active == false
      assert rule2_reloaded.active == true
    end
  end

  # Helper function to create library playlists for testing
  defp library_playlist_fixture(user, attrs \\ %{}) do
    default_attrs = %{
      provider: :spotify,
      playlist_id: "playlist_#{System.unique_integer([:positive])}",
      title: "Test Playlist",
      url: "https://open.spotify.com/playlist/test",
      public: true,
      track_count: 10
    }

    attrs = Map.merge(default_attrs, attrs)

    {:ok, playlist} = LibraryPlaylist.create(user, attrs)
    playlist
  end
end
