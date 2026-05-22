defmodule PremiereEcoute.Playlists.PlaylistSubscriptionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.PlaylistSubscription

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

  describe "subscribe/3" do
    test "creates a subscription with the given channel" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert {:ok, sub} = PlaylistSubscription.subscribe(playlist, user, :email)
      assert sub.user_id == user.id
      assert sub.library_playlist_id == playlist.id
      assert :email in sub.channels
    end

    test "adds a new channel to an existing subscription" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :email)
      assert {:ok, sub} = PlaylistSubscription.subscribe(playlist, user, :discord)
      assert :email in sub.channels
      assert :discord in sub.channels
    end

    test "is idempotent when subscribing to the same channel twice" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :email)
      assert {:ok, sub} = PlaylistSubscription.subscribe(playlist, user, :email)
      assert sub.channels == [:email]
    end
  end

  describe "unsubscribe/3" do
    test "removes the channel from the subscription" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :email)
      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :discord)
      assert {:ok, sub} = PlaylistSubscription.unsubscribe(playlist, user, :email)
      assert :email not in sub.channels
      assert :discord in sub.channels
    end

    test "deletes the row when the last channel is removed" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :email)
      assert {:ok, :deleted} = PlaylistSubscription.unsubscribe(playlist, user, :email)
      refute PlaylistSubscription.subscribed?(playlist, user, :email)
    end

    test "returns :not_found when no subscription exists" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert {:error, :not_found} = PlaylistSubscription.unsubscribe(playlist, user, :email)
    end
  end

  describe "subscribed?/3" do
    test "returns true when user is subscribed via the given channel" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :email)
      assert PlaylistSubscription.subscribed?(playlist, user, :email)
    end

    test "returns false when user is not subscribed" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      refute PlaylistSubscription.subscribed?(playlist, user, :email)
    end

    test "returns false for a channel the user has not subscribed to" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      {:ok, _} = PlaylistSubscription.subscribe(playlist, user, :email)
      refute PlaylistSubscription.subscribed?(playlist, user, :discord)
    end
  end

  describe "list_subscribers/2" do
    test "returns users subscribed via the given channel" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer1 = user_fixture()
      viewer2 = user_fixture()

      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer1, :email)
      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer2, :email)

      subscribers = PlaylistSubscription.list_subscribers(playlist, :email)
      ids = Enum.map(subscribers, & &1.id)
      assert viewer1.id in ids
      assert viewer2.id in ids
    end

    test "does not return users subscribed via a different channel" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer = user_fixture()

      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer, :discord)

      assert PlaylistSubscription.list_subscribers(playlist, :email) == []
    end

    test "returns empty list when no subscribers" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert PlaylistSubscription.list_subscribers(playlist, :email) == []
    end
  end

  describe "subscriber_count/1" do
    test "returns the total number of distinct subscribers" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer1 = user_fixture()
      viewer2 = user_fixture()

      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer1, :email)
      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer2, :email)

      assert PlaylistSubscription.subscriber_count(playlist) == 2
    end

    test "counts a user once even if subscribed to multiple channels" do
      streamer = user_fixture()
      playlist = library_playlist_fixture(streamer)
      viewer = user_fixture()

      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer, :email)
      {:ok, _} = PlaylistSubscription.subscribe(playlist, viewer, :discord)

      assert PlaylistSubscription.subscriber_count(playlist) == 1
    end

    test "returns 0 when no subscribers" do
      user = user_fixture()
      playlist = library_playlist_fixture(user)

      assert PlaylistSubscription.subscriber_count(playlist) == 0
    end
  end
end
