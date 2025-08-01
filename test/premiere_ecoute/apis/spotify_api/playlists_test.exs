defmodule PremiereEcoute.Apis.SpotifyApi.PlaylistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Core.Cache

  alias PremiereEcoute.Sessions.Discography.Playlist
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  setup_all do
    Cache.put(:tokens, :spotify, "token")

    :ok
  end

  describe "get_playlist/1" do
    test "list playlist from an unique identifier" do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7"},
        response: "spotify_api/playlists/get_playlist/response.json",
        status: 200
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      {:ok, playlist} = SpotifyApi.get_playlist(id)

      assert %Playlist{
               spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
               spotify_owner_id: "ku296zgwbo0e3qff8cylptsjq",
               owner_name: "Flonflon",
               name: "FLONFLON MUSIC FRIDAY",
               cover_url: cover_url,
               tracks: tracks
             } = playlist

      assert Regex.match?(~r/^https:\/\/image-cdn-[a-z0-9\-]+\.spotifycdn\.com\/image\/[a-f0-9]{40}$/, cover_url)

      for track <- tracks do
        assert %Track{} = track
      end
    end
  end

  describe "get_user_playlists/1" do
    test "get a list of the playlists owned or followed by the current Spotify user" do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me/playlists"},
        response: "spotify_api/playlists/get_current_user_playlist/response.json",
        status: 200
      )

      scope = user_scope_fixture(user_fixture())

      {:ok, playlists} = SpotifyApi.get_user_playlists(scope)

      assert playlists == [
               %PremiereEcoute.Sessions.Discography.Playlist{
                 id: nil,
                 spotify_id: "5dIzUBcdljrcjJLP3B6ZLk",
                 name: "La playlist idéale : les propositions",
                 spotify_owner_id: "ku296zgwbo0e3qff8cylptsjq",
                 owner_name: "Flonflon",
                 cover_url:
                   "https://mosaic.scdn.co/300/ab67616d00001e0224eb40775d2ad89181f93630ab67616d00001e0260863211a34118f09d8f6434ab67616d00001e02ae871c52286bf992400f4002ab67616d00001e02b85976e1b1bd2d00ff551a01",
                 tracks: [],
                 inserted_at: nil,
                 updated_at: nil
               },
               %PremiereEcoute.Sessions.Discography.Playlist{
                 id: nil,
                 spotify_id: "4ulqK1y6myPKOe3bNUEfvr",
                 name: "Cérémonie d'ouverture JO Paris 2024",
                 spotify_owner_id: "11124351208",
                 owner_name: "Ervan Couderc",
                 cover_url: "https://image-cdn-ak.spotifycdn.com/image/ab67706c0000d72cc71cd11ee39285e0e565b684",
                 tracks: [],
                 inserted_at: nil,
                 updated_at: nil
               }
             ]
    end
  end

  describe "add_items_to_playlist/1" do
    test "add one or more items to a user's playlist" do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7/tracks"},
        request: "spotify_api/playlists/add_items_to_playlist/request.json",
        response: "spotify_api/playlists/add_items_to_playlist/response.json",
        status: 201
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      scope = user_scope_fixture(user_fixture())

      tracks = [%Track{spotify_id: "3QaPy1KgI7nu9FJEQUgn6h"}, %Track{spotify_id: "6TGd66r0nlPaYm3KIoI7ET"}]

      {:ok, snapshot} = SpotifyApi.add_items_to_playlist(scope, id, tracks)

      assert snapshot == %{"snapshot_id" => "abc"}
    end
  end

  describe "remove_playlist_items/1" do
    test "remove one or more items to a user's playlist" do
      ApiMock.expect(
        SpotifyApi,
        path: {:delete, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7/tracks"},
        request: "spotify_api/playlists/remove_playlist_items/request.json",
        response: "spotify_api/playlists/remove_playlist_items/response.json",
        status: 200
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      scope = user_scope_fixture(user_fixture())

      tracks = [%Track{spotify_id: "3QaPy1KgI7nu9FJEQUgn6h"}, %Track{spotify_id: "6TGd66r0nlPaYm3KIoI7ET"}]
      snapshot = %{"snapshot_id" => "abc"}

      {:ok, snapshot} = SpotifyApi.remove_playlist_items(scope, id, tracks, snapshot)

      assert snapshot == %{"snapshot_id" => "def"}
    end
  end
end
