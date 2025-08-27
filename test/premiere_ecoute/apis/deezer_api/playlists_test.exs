defmodule PremiereEcoute.Apis.DeezerApi.PlaylistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.DeezerApi

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  describe "get_playlist/1" do
    test "get a playlist from an unique identifier" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/playlist/908622995"},
        headers: [{"content-type", "application/json"}],
        response: "deezer_api/playlists/get_playlist/response.json",
        status: 200
      )

      id = "908622995"

      {:ok, playlist} = DeezerApi.get_playlist(id)

      assert %Playlist{
               provider: :deezer,
               playlist_id: "908622995",
               owner_id: "1687950",
               owner_name: "Alexandre - Pop & Hits Editor",
               title: "En mode 60",
               cover_url:
                 "https://cdn-images.dzcdn.net/images/playlist/4fd375a41c7779ed7deab64fb1194099/250x250-000000-80-0-0.jpg",
               tracks: [track | _] = tracks
             } = playlist

      assert track == %Track{
               provider: :deezer,
               track_id: "366450991",
               album_id: "42219371",
               name: "Nights In White Satin",
               artist: "The Moody Blues",
               release_date: ~D[1900-01-01],
               duration_ms: 265_000
             }

      for track <- tracks do
        assert %Track{} = track
      end
    end
  end
end
