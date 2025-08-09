defmodule PremiereEcoute.Apis.SpotifyApi.SearchTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Core.Cache

  alias PremiereEcoute.Discography.Album

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
  end

  describe "search_albums/1" do
    test "can list albums from a string query", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/search"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        params: %{"q" => "billie", "type" => "album", "limit" => "20"},
        response: "spotify_api/search/search_for_item/billie.json",
        status: 200
      )

      query = "billie"

      {:ok, albums} = SpotifyApi.search_albums(query)

      for %Album{} = album <- albums do
        assert Enum.sort(Map.keys(album)) == [
                 :__meta__,
                 :__struct__,
                 :album_id,
                 :artist,
                 :cover_url,
                 :id,
                 :inserted_at,
                 :name,
                 :provider,
                 :release_date,
                 :total_tracks,
                 :tracks,
                 :updated_at
               ]
      end

      assert %Album{
               id: nil,
               provider: :spotify,
               album_id: "7aJuG4TFXa2hmE4z1yxc3n",
               name: "HIT ME HARD AND SOFT",
               artist: "Billie Eilish",
               release_date: ~D[2024-05-17],
               cover_url: "https://i.scdn.co/image/ab67616d00001e0271d62ea7ea8a5be92d3c1f62",
               tracks: [],
               total_tracks: 10
             } in albums
    end
  end
end
