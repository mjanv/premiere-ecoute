defmodule PremiereEcoute.Playlists.Workers.PlaylistEmailWorkerTest do
  use PremiereEcoute.DataCase, async: true

  import Swoosh.TestAssertions

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.PlaylistFixtures
  alias PremiereEcoute.Playlists.Workers.PlaylistEmailWorker

  setup :verify_on_exit!

  setup do
    user = user_fixture(%{email: "listener@example.com"})
    playlist = collection_library_playlist_fixture(user, %{title: "My Playlist"})
    {:ok, user: user, playlist: playlist}
  end

  describe "perform/1" do
    test "delivers an email to the user's address", %{user: user, playlist: playlist} do
      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, PlaylistFixtures.playlist_fixture()} end)

      :ok = perform_job(PlaylistEmailWorker, %{"playlist_id" => playlist.id, "user_id" => user.id})

      assert_email_sent(
        to: [{"", "listener@example.com"}],
        subject: "Playlist: My Playlist"
      )
    end

    test "returns error when playlist not found", %{user: user} do
      assert {:error, :not_found} =
               perform_job(PlaylistEmailWorker, %{"playlist_id" => -1, "user_id" => user.id})
    end

    test "returns error when Spotify API fails", %{user: user, playlist: playlist} do
      expect(SpotifyApi, :get_playlist, fn _id -> {:error, :timeout} end)

      assert {:error, :timeout} =
               perform_job(PlaylistEmailWorker, %{"playlist_id" => playlist.id, "user_id" => user.id})
    end
  end
end
