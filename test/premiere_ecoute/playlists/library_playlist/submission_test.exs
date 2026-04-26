defmodule PremiereEcoute.Playlists.LibraryPlaylist.SubmissionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.LibraryPlaylist.Submission

  defp library_playlist_fixture(user) do
    {:ok, playlist} =
      LibraryPlaylist.create(user, %{
        provider: :spotify,
        playlist_id: "pl_#{System.unique_integer([:positive])}",
        title: "Test Playlist",
        url: "https://open.spotify.com/playlist/test"
      })

    playlist
  end

  defp submission_fixture(playlist, user, provider_id \\ nil) do
    provider_id = provider_id || "track_#{System.unique_integer([:positive])}"
    {:ok, submission} = Submission.create(playlist, user, provider_id)
    submission
  end

  describe "create/3" do
    test "records a submission" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert {:ok, submission} = Submission.create(playlist, user, "spotify_track_id")
      assert submission.provider_id == "spotify_track_id"
      assert submission.user_id == user.id
      assert submission.library_playlist_id == playlist.id
    end

    test "rejects duplicate (same playlist, user, track)" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = Submission.create(playlist, user, "track_abc")
      assert {:error, changeset} = Submission.create(playlist, user, "track_abc")
      assert errors_on(changeset)[:library_playlist_id] == ["has already been taken"]
    end

    test "allows same track submitted by different viewers" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer1 = user_fixture()
      viewer2 = user_fixture()

      assert {:ok, _} = Submission.create(playlist, viewer1, "track_abc")
      assert {:ok, _} = Submission.create(playlist, viewer2, "track_abc")
    end
  end

  describe "count_for_viewer/2" do
    test "returns 0 when viewer has no submissions" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert Submission.count_for_viewer(playlist, user) == 0
    end

    test "returns the correct count for the viewer" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer = user_fixture()

      submission_fixture(playlist, viewer)
      submission_fixture(playlist, viewer)

      assert Submission.count_for_viewer(playlist, viewer) == 2
    end

    test "does not count submissions from other viewers" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer1 = user_fixture()
      viewer2 = user_fixture()

      submission_fixture(playlist, viewer1)
      submission_fixture(playlist, viewer1)
      submission_fixture(playlist, viewer2)

      assert Submission.count_for_viewer(playlist, viewer1) == 2
      assert Submission.count_for_viewer(playlist, viewer2) == 1
    end
  end

  describe "list_for_viewer/2" do
    test "returns submissions ordered by insertion date" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer = user_fixture()

      s1 = submission_fixture(playlist, viewer, "track_1")
      s2 = submission_fixture(playlist, viewer, "track_2")

      result = Submission.list_for_viewer(playlist, viewer)
      assert Enum.map(result, & &1.id) == [s1.id, s2.id]
    end

    test "does not return submissions from other viewers" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer1 = user_fixture()
      viewer2 = user_fixture()

      submission_fixture(playlist, viewer1, "track_a")
      submission_fixture(playlist, viewer2, "track_b")

      result = Submission.list_for_viewer(playlist, viewer1)
      assert length(result) == 1
      assert hd(result).provider_id == "track_a"
    end

    test "returns empty list when viewer has no submissions" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert Submission.list_for_viewer(playlist, user) == []
    end
  end

  describe "delete_for_viewer/3" do
    test "deletes the submission and returns it" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)
      submission_fixture(playlist, user, "track_xyz")

      assert {:ok, deleted} = Submission.delete_for_viewer(playlist, user, "track_xyz")
      assert deleted.provider_id == "track_xyz"
      assert Submission.count_for_viewer(playlist, user) == 0
    end

    test "returns :not_found when submission does not exist" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert {:error, :not_found} = Submission.delete_for_viewer(playlist, user, "nonexistent")
    end

    test "returns :not_found when submission belongs to another viewer" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer1 = user_fixture()
      viewer2 = user_fixture()

      submission_fixture(playlist, viewer1, "track_xyz")

      assert {:error, :not_found} = Submission.delete_for_viewer(playlist, viewer2, "track_xyz")
      assert Submission.count_for_viewer(playlist, viewer1) == 1
    end
  end

  describe "delete_stale/2" do
    test "deletes submissions whose track is no longer in the playlist" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)
      viewer = user_fixture()

      submission_fixture(playlist, viewer, "track_removed")
      submission_fixture(playlist, viewer, "track_kept")

      deleted = Submission.delete_stale(playlist, ["track_kept"])

      assert deleted == 1
      remaining = Submission.list_for_viewer(playlist, viewer)
      assert Enum.map(remaining, & &1.provider_id) == ["track_kept"]
    end

    test "deletes nothing when all tracks are still present" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)
      viewer = user_fixture()

      submission_fixture(playlist, viewer, "track_a")
      submission_fixture(playlist, viewer, "track_b")

      deleted = Submission.delete_stale(playlist, ["track_a", "track_b", "track_c"])

      assert deleted == 0
      assert Submission.count_for_viewer(playlist, viewer) == 2
    end

    test "does nothing when live list is empty (guards against transient empty Spotify response)" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)
      viewer = user_fixture()

      submission_fixture(playlist, viewer, "track_1")
      submission_fixture(playlist, viewer, "track_2")

      deleted = Submission.delete_stale(playlist, [])

      assert deleted == 0
      assert Submission.count_for_viewer(playlist, viewer) == 2
    end

    test "only affects submissions for the given playlist" do
      streamer = user_fixture()
      playlist1 = library_playlist_fixture(streamer)
      playlist2 = library_playlist_fixture(streamer)
      viewer = user_fixture()

      submission_fixture(playlist1, viewer, "track_gone")
      submission_fixture(playlist2, viewer, "track_gone")

      # "track_gone" is absent from playlist1's live list but present in playlist2's
      Submission.delete_stale(playlist1, ["some_other_track"])

      assert Submission.count_for_viewer(playlist1, viewer) == 0
      assert Submission.count_for_viewer(playlist2, viewer) == 1
    end
  end
end
