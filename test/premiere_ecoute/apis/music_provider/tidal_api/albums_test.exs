defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.AlbumsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.TidalApi

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()
    PremiereEcouteCore.Cache.put(:tokens, :tidal, token)
    {:ok, %{token: token}}
  end

  describe "get_album/1" do
    test "fetches an album with tracks by Tidal ID", %{token: token} do
      ApiMock.expect(
        TidalApi,
        path: {:get, "/v2/albums"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"}
        ],
        response: "tidal_api/albums/get_album/response.json",
        status: 200
      )

      {:ok, album} = TidalApi.get_album("21161733")

      assert %Album{
               id: nil,
               provider_ids: %{tidal: "21161733"},
               name: "Magna Carta... Holy Grail",
               artist: "JAŸ-Z",
               release_date: ~D[2013-07-09],
               cover_url: "https://resources.tidal.com/images/6f520354/d497/4309/bc2f/ca3e941cd9ef/750x750.jpg",
               total_tracks: 16,
               tracks: [
                 %Track{
                   id: nil,
                   provider_ids: %{tidal: "21161734"},
                   name: "Holy Grail",
                   track_number: 1,
                   duration_ms: 338_000
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{tidal: "21161735"},
                   name: "Picasso Baby",
                   track_number: 2,
                   duration_ms: 245_000
                 }
                 | _
               ]
             } = album

      assert length(album.tracks) == 16
    end
  end
end
