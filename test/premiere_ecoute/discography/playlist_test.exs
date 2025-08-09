defmodule PremiereEcoute.Discography.PlaylistTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcoute.Repo

  describe "create/1" do
    test "creates an playlist with tracks" do
      {:ok, playlist} = Playlist.create(playlist_fixture())

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               owner_id: "ku296zgwbo0e3qff8cylptsjq",
               owner_name: "Flonflon",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "does not recreate an existing playlist" do
      {:ok, _} = Playlist.create(playlist_fixture())
      {:error, changeset} = Playlist.create(playlist_fixture())

      assert Repo.traverse_errors(changeset) == %{playlist_id: ["has already been taken"]}
    end
  end

  describe "create_if_not_exists/1" do
    test "create an unexisting playlist" do
      {:ok, playlist} = Playlist.create_if_not_exists(playlist_fixture())

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "does not recreate an existing playlist" do
      {:ok, _} = Playlist.create_if_not_exists(playlist_fixture())
      {:ok, playlist} = Playlist.create_if_not_exists(playlist_fixture())

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
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
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
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
      {:ok, %Playlist{playlist_id: playlist_id}} = Playlist.create(playlist_fixture())

      playlist = Playlist.get_by(playlist_id: playlist_id)

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
               tracks: [
                 %Track{
                   provider: :spotify,
                   name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
                   track_id: "4gVsKMMK0f8dweHL7Vm9HC",
                   album_id: "7eD4M0bxUGIFRCi0wWhkbt",
                   user_id: "ku296zgwbo0e3qff8cylptsjq",
                   artist: "Unknown Artist",
                   duration_ms: 217_901,
                   added_at: ~N[2025-07-18 07:59:47]
                 }
               ]
             } = playlist
    end

    test "get an unexisting playlist" do
      assert is_nil(Playlist.get_by(playlist_id: "unknown"))
    end
  end

  describe "delete/1" do
    test "delete an existing playlist" do
      {:ok, %Playlist{playlist_id: playlist_id} = playlist} = Playlist.create(playlist_fixture())

      {:ok, _} = Playlist.delete(playlist)

      assert is_nil(Playlist.get_by(playlist_id: playlist_id))
    end
  end
end
