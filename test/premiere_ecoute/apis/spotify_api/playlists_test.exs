defmodule PremiereEcoute.Apis.SpotifyApi.PlaylistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
  end

  describe "get_playlist/1" do
    test "get a playlist from an unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/playlists/get_playlist/response.json",
        status: 200
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      {:ok, playlist} = SpotifyApi.get_playlist(id)

      assert %Playlist{
               provider: :spotify,
               playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
               owner_id: "ku296zgwbo0e3qff8cylptsjq",
               owner_name: "Flonflon",
               title: "FLONFLON MUSIC FRIDAY",
               cover_url: cover_url,
               tracks: tracks
             } = playlist

      assert Regex.match?(~r/^https:\/\/image-cdn-[a-z0-9\-]+\.spotifycdn\.com\/image\/[a-f0-9]{40}$/, cover_url)

      for track <- tracks do
        assert %Track{release_date: _} = track
      end
    end
  end

  describe "get_library_playlists/1" do
    test "get a list of the playlists owned or followed by the current Spotify user" do
      ApiMock.expect(
        SpotifyApi,
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        params: %{"limit" => "10", "offset" => "0"},
        path: {:get, "/v1/me/playlists"},
        response: "spotify_api/playlists/get_current_user_playlist/response.json",
        status: 200
      )

      scope = user_scope_fixture(user_fixture(%{spotify: %{access_token: "access_token"}}))

      {:ok, playlists} = SpotifyApi.get_library_playlists(scope)

      assert [
               %LibraryPlaylist{
                 id: nil,
                 provider: :spotify,
                 playlist_id: "5dIzUBcdljrcjJLP3B6ZLk",
                 url: "https://open.spotify.com/playlist/5dIzUBcdljrcjJLP3B6ZLk",
                 title: "La playlist idéale : les propositions",
                 description: "",
                 cover_url:
                   "https://mosaic.scdn.co/300/ab67616d00001e0224eb40775d2ad89181f93630ab67616d00001e0260863211a34118f09d8f6434ab67616d00001e02ae871c52286bf992400f4002ab67616d00001e02b85976e1b1bd2d00ff551a01",
                 public: true,
                 track_count: nil,
                 metadata: %{},
                 user_id: nil,
                 inserted_at: nil,
                 updated_at: nil
               },
               %LibraryPlaylist{
                 id: nil,
                 provider: :spotify,
                 playlist_id: "4ulqK1y6myPKOe3bNUEfvr",
                 url: "https://open.spotify.com/playlist/4ulqK1y6myPKOe3bNUEfvr",
                 title: "Cérémonie d'ouverture JO Paris 2024",
                 description: "Tous les titres joués, dans l&#x27;ordre chronologique. #Paris2024",
                 cover_url: "https://image-cdn-ak.spotifycdn.com/image/ab67706c0000d72cc71cd11ee39285e0e565b684",
                 public: true,
                 track_count: nil,
                 metadata: %{},
                 user_id: nil,
                 inserted_at: nil,
                 updated_at: nil
               }
             ] = playlists
    end
  end

  describe "create_playlist/2" do
    test "create a playlist" do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/users/lanfeust313/playlists"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "spotify_api/playlists/create_playlist/request.json",
        response: "spotify_api/playlists/create_playlist/response.json",
        status: 201
      )

      scope = user_scope_fixture(user_fixture(%{spotify: %{user_id: "lanfeust313", access_token: "access_token"}}))

      playlist = %LibraryPlaylist{title: "New Playlist", description: "New playlist description", public: false}

      {:ok, playlist} = SpotifyApi.create_playlist(scope, playlist)

      assert playlist == %LibraryPlaylist{
               provider: :spotify,
               playlist_id: "49TgLmDb4WA8FN1nKUIe9G",
               title: "New Playlist",
               description: "New playlist description",
               url: "https://open.spotify.com/playlist/49TgLmDb4WA8FN1nKUIe9G",
               cover_url: nil,
               public: false,
               track_count: 0,
               metadata: %{}
             }
    end
  end

  describe "add_items_to_playlist/3" do
    test "add one or more items to a user's playlist" do
      ApiMock.expect(
        SpotifyApi,
        path: {:post, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7/tracks"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "spotify_api/playlists/add_items_to_playlist/request.json",
        response: "spotify_api/playlists/add_items_to_playlist/response.json",
        status: 201
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      scope = user_scope_fixture(user_fixture(%{spotify: %{access_token: "access_token"}}))

      tracks = [%Track{track_id: "3QaPy1KgI7nu9FJEQUgn6h"}, %Track{track_id: "6TGd66r0nlPaYm3KIoI7ET"}]

      {:ok, snapshot} = SpotifyApi.add_items_to_playlist(scope, id, tracks)

      assert snapshot == %{"snapshot_id" => "abc"}
    end
  end

  describe "replace_items_to_playlist/1" do
    test "add one or more items to a user's playlist" do
      ApiMock.expect(
        SpotifyApi,
        path: {:put, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7/tracks"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "spotify_api/playlists/add_items_to_playlist/request_replace.json",
        response: "spotify_api/playlists/add_items_to_playlist/response_replace.json",
        status: 200
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      scope = user_scope_fixture(user_fixture(%{spotify: %{access_token: "access_token"}}))

      tracks = [%Track{track_id: "3QaPy1KgI7nu9FJEQUgn6h"}, %Track{track_id: "6TGd66r0nlPaYm3KIoI7ET"}]

      {:ok, snapshot} = SpotifyApi.replace_items_to_playlist(scope, id, tracks)

      assert snapshot == %{"snapshot_id" => "def"}
    end
  end

  describe "remove_playlist_items/1" do
    test "remove one or more items to a user's playlist" do
      ApiMock.expect(
        SpotifyApi,
        path: {:delete, "/v1/playlists/2gW4sqiC2OXZLe9m0yDQX7/tracks"},
        headers: [
          {"authorization", "Bearer access_token"},
          {"content-type", "application/json"}
        ],
        request: "spotify_api/playlists/remove_playlist_items/request.json",
        response: "spotify_api/playlists/remove_playlist_items/response.json",
        status: 200
      )

      id = "2gW4sqiC2OXZLe9m0yDQX7"

      scope = user_scope_fixture(user_fixture(%{spotify: %{access_token: "access_token"}}))

      tracks = [%Track{track_id: "3QaPy1KgI7nu9FJEQUgn6h"}, %Track{track_id: "6TGd66r0nlPaYm3KIoI7ET"}]

      {:ok, snapshot} = SpotifyApi.remove_playlist_items(scope, id, tracks)

      assert snapshot == %{"snapshot_id" => "def"}
    end
  end
end
