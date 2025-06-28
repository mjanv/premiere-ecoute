defmodule PremiereEcoute.Apis.SpotifyApi.SearchTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.SpotifyApi

  alias PremiereEcoute.Core.Entities.Album

  describe "search_albums/1" do
    test "can list albums from a string query" do
      query = "billie"

      {:ok, albums} = SpotifyApi.search_albums(query)

      for %Album{} = album <- albums do
        assert Enum.sort(Map.keys(album)) == [
                 :__struct__,
                 :artist,
                 :cover_url,
                 :id,
                 :name,
                 :release_date,
                 :spotify_id,
                 :total_tracks,
                 :tracks
               ]
      end

      assert %Album{
               id: nil,
               spotify_id: "7aJuG4TFXa2hmE4z1yxc3n",
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
