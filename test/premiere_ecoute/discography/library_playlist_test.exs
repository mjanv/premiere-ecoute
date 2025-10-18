defmodule PremiereEcoute.Discography.LibraryPlaylistTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.LibraryPlaylist

  describe "create/2" do
    test "creates a library playlist with valid attributes" do
      user = user_fixture()

      attrs = %{
        provider: :spotify,
        playlist_id: "playlist123",
        title: "My Awesome Playlist",
        description: "A great collection of songs",
        url: "https://open.spotify.com/playlist/playlist123",
        cover_url: "https://example.com/cover.jpg",
        public: true,
        track_count: 25,
        metadata: %{"custom_field" => "value"}
      }

      {:ok, playlist} = LibraryPlaylist.create(user, attrs)

      assert %LibraryPlaylist{
               provider: :spotify,
               playlist_id: "playlist123",
               title: "My Awesome Playlist",
               description: "A great collection of songs",
               url: "https://open.spotify.com/playlist/playlist123",
               cover_url: "https://example.com/cover.jpg",
               public: true,
               track_count: 25,
               metadata: %{"custom_field" => "value"},
               user_id: user_id
             } = playlist

      assert user_id == user.id
    end

    test "creates a library playlist with minimal required attributes" do
      user = user_fixture()

      attrs = %{
        provider: :deezer,
        playlist_id: "deezer456",
        title: "Minimal Playlist",
        url: "https://deezer.com/playlist/456"
      }

      {:ok, playlist} = LibraryPlaylist.create(user, attrs)

      assert %LibraryPlaylist{
               provider: :deezer,
               playlist_id: "deezer456",
               title: "Minimal Playlist",
               url: "https://deezer.com/playlist/456",
               user_id: user_id,
               description: nil,
               cover_url: nil,
               public: true,
               track_count: nil,
               metadata: nil
             } = playlist

      assert user_id == user.id
    end

    test "fails when required fields are missing" do
      user = user_fixture()

      attrs = %{
        provider: :spotify,
        playlist_id: "playlist123"
      }

      {:error, changeset} = LibraryPlaylist.create(user, attrs)

      assert errors_on(changeset) == %{
               title: ["can't be blank"],
               url: ["can't be blank"]
             }
    end

    test "fails with invalid provider" do
      user = user_fixture()

      attrs = %{
        provider: :invalid_provider,
        playlist_id: "playlist123",
        title: "Test Playlist",
        url: "https://example.com/playlist"
      }

      assert {:error, changeset} = LibraryPlaylist.create(user, attrs)

      assert errors_on(changeset) == %{provider: ["is invalid"]}
    end

    test "fails when playlist_id and provider combination already exists" do
      user = user_fixture()

      attrs = %{
        provider: :spotify,
        playlist_id: "duplicate123",
        title: "First Playlist",
        url: "https://open.spotify.com/playlist/duplicate123"
      }

      {:ok, _} = LibraryPlaylist.create(user, attrs)
      {:error, changeset} = LibraryPlaylist.create(user, attrs)

      assert errors_on(changeset) == %{user_id: ["has already been taken"]}
    end
  end

  describe "exists?/2" do
    test "returns true when playlist exists for user" do
      user = user_fixture()

      attrs = %{
        provider: :spotify,
        playlist_id: "exists123",
        title: "Existing Playlist",
        url: "https://open.spotify.com/playlist/exists123"
      }

      {:ok, playlist} = LibraryPlaylist.create(user, attrs)

      assert LibraryPlaylist.exists?(user, playlist)
    end

    test "returns false when playlist does not exist for user" do
      user = user_fixture()

      playlist = %LibraryPlaylist{provider: :spotify, playlist_id: "nonexistent123"}

      refute LibraryPlaylist.exists?(user, playlist)
    end

    test "returns false when playlist exists for different user" do
      user1 = user_fixture()
      user2 = user_fixture()

      attrs = %{
        provider: :deezer,
        playlist_id: "different456",
        title: "User1 Playlist",
        url: "https://deezer.com/playlist/different456"
      }

      {:ok, playlist} = LibraryPlaylist.create(user1, attrs)

      refute LibraryPlaylist.exists?(user2, playlist)
    end
  end
end
