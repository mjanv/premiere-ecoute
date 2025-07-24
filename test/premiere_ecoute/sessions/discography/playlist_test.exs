defmodule PremiereEcoute.Sessions.Discography.PlaylistTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Playlist
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  describe "create/1" do
    test "creates an playlist with tracks" do
      {:ok, playlist} = Playlist.create(playlist_fixture())

      assert %Playlist{
        spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
        name: "FLONFLON MUSIC FRIDAY",
        spotify_owner_id: "ku296zgwbo0e3qff8cylptsjq",
        owner_name: "Flonflon",
        cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
        tracks: [
          %Track{
            name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
            spotify_id: "4gVsKMMK0f8dweHL7Vm9HC",
            album_spotify_id: "7eD4M0bxUGIFRCi0wWhkbt",
            user_spotify_id: "ku296zgwbo0e3qff8cylptsjq",
            artist: "Unknown Artist",
            duration_ms: 217901,
            added_at: ~N[2025-07-18 07:59:47],
          }
        ]
      } = playlist
    end

    test "does not recreate an existing playlist" do
      {:ok, _} = Playlist.create(playlist_fixture())
      {:error, changeset} = Playlist.create(playlist_fixture())

      assert Repo.traverse_errors(changeset) == %{spotify_id: ["has already been taken"]}
    end
  end

  describe "create_if_not_exists/1" do
    test "create an unexisting playlist" do
      {:ok, playlist} = Playlist.create_if_not_exists(playlist_fixture())

      assert %Playlist{
        spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
        name: "FLONFLON MUSIC FRIDAY",
        cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
        tracks: [
          %Track{
            name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
            spotify_id: "4gVsKMMK0f8dweHL7Vm9HC",
            album_spotify_id: "7eD4M0bxUGIFRCi0wWhkbt",
            user_spotify_id: "ku296zgwbo0e3qff8cylptsjq",
            artist: "Unknown Artist",
            duration_ms: 217901,
            added_at: ~N[2025-07-18 07:59:47],
          }
        ]
      } = playlist
    end

    test "does not recreate an existing playlist" do
      {:ok, _} = Playlist.create_if_not_exists(playlist_fixture())
      {:ok, playlist} = Playlist.create_if_not_exists(playlist_fixture())

      assert %Playlist{
        spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
        name: "FLONFLON MUSIC FRIDAY",
        cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
        tracks: [
          %Track{
            name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
            spotify_id: "4gVsKMMK0f8dweHL7Vm9HC",
            album_spotify_id: "7eD4M0bxUGIFRCi0wWhkbt",
            user_spotify_id: "ku296zgwbo0e3qff8cylptsjq",
            artist: "Unknown Artist",
            duration_ms: 217901,
            added_at: ~N[2025-07-18 07:59:47],
          }
        ]
      } = playlist
    end
  end

  describe "get/1" do
    test "get an existing playlist" do
      {:ok, %Playlist{id: id}} = Playlist.create(playlist_fixture())

      playlist = Playlist.get(id)

      assert %Playlist{
        spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
        name: "FLONFLON MUSIC FRIDAY",
        cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
        tracks: [
          %Track{
            name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
            spotify_id: "4gVsKMMK0f8dweHL7Vm9HC",
            album_spotify_id: "7eD4M0bxUGIFRCi0wWhkbt",
            user_spotify_id: "ku296zgwbo0e3qff8cylptsjq",
            artist: "Unknown Artist",
            duration_ms: 217901,
            added_at: ~N[2025-07-18 07:59:47],
          }
        ]
      } = playlist
    end

    test "get an unexisting playlist" do
      assert is_nil(Playlist.get(-1))
    end
  end

  describe "get_by/1" do
    test "get an existing playlist" do
      {:ok, %Playlist{spotify_id: spotify_id}} = Playlist.create(playlist_fixture())

      playlist = Playlist.get_by(spotify_id: spotify_id)

      assert %Playlist{
        spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
        name: "FLONFLON MUSIC FRIDAY",
        cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
        tracks: [
          %Track{
            name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
            spotify_id: "4gVsKMMK0f8dweHL7Vm9HC",
            album_spotify_id: "7eD4M0bxUGIFRCi0wWhkbt",
            user_spotify_id: "ku296zgwbo0e3qff8cylptsjq",
            artist: "Unknown Artist",
            duration_ms: 217901,
            added_at: ~N[2025-07-18 07:59:47],
          }
        ]
      } = playlist
    end

    test "get an unexisting playlist" do
      assert is_nil(Playlist.get_by(spotify_id: "unknown"))
    end
  end

  describe "delete/1" do
    test "delete an existing playlist" do
      {:ok, %Playlist{spotify_id: spotify_id} = playlist} = Playlist.create(playlist_fixture())

      {:ok, _} = Playlist.delete(playlist)

      assert is_nil(Playlist.get_by(spotify_id: spotify_id))
    end
  end
end
