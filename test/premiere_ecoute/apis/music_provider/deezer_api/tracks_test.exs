defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.TracksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi

  alias PremiereEcoute.Discography.Album.Track

  setup {Req.Test, :verify_on_exit!}

  describe "get_track/1" do
    test "returns track details from a unique identifier" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/track/3135556"},
        headers: [{"content-type", "application/json"}],
        response: "deezer_api/albums/get_track/response.json",
        status: 200
      )

      id = "3135556"

      {:ok, track} = DeezerApi.get_track(id)

      assert %Track{
               id: nil,
               provider: :deezer,
               track_id: "3135556",
               album_id: "302127",
               name: "Harder, Better, Faster, Stronger",
               track_number: 4,
               duration_ms: 226_000
             } = track
    end
  end
end
