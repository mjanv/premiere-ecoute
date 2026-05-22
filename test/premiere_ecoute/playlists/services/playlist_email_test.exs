defmodule PremiereEcoute.Playlists.Services.PlaylistEmailTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Playlists.Services.PlaylistEmail
  alias PremiereEcoute.Playlists.Workers.PlaylistEmailWorker

  setup do
    user = user_fixture()
    playlist = collection_library_playlist_fixture(user, %{title: "My Playlist"})
    {:ok, user: user, playlist: playlist}
  end

  describe "email/2 with a single user" do
    test "enqueues one job", %{user: user, playlist: playlist} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, [_job]} = PlaylistEmail.email(playlist, user)

        assert_enqueued(worker: PlaylistEmailWorker, args: %{"playlist_id" => playlist.id, "user_id" => user.id})
      end)
    end
  end

  describe "email/2 with a list of users" do
    test "enqueues one job per user", %{user: user, playlist: playlist} do
      other_user = user_fixture(%{email: "other@example.com"})

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, jobs} = PlaylistEmail.email(playlist, [user, other_user])

        assert length(jobs) == 2

        assert_enqueued(worker: PlaylistEmailWorker, args: %{"playlist_id" => playlist.id, "user_id" => user.id})
        assert_enqueued(worker: PlaylistEmailWorker, args: %{"playlist_id" => playlist.id, "user_id" => other_user.id})
      end)
    end

    test "returns ok with empty list when no users given", %{playlist: playlist} do
      assert {:ok, []} = PlaylistEmail.email(playlist, [])
    end
  end
end
