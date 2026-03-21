defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi.RecordingsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_recordings/1" do
    test "returns recording results for a query" do
      ApiMock.expect(
        MusicBrainzApi,
        path: {:get, "/ws/2/recording"},
        headers: [{"user-agent", "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "musicbrainz_api/recordings/search_recordings/response.json",
        status: 200
      )

      {:ok, recordings} = MusicBrainzApi.search_recordings(~s(recording:"One More Time" AND artist:"Daft Punk"))

      assert length(recordings) == 10

      assert [
               %{
                 mbid: "2b9d2766-23aa-473d-89d8-85ec509757db",
                 title: "One More Time",
                 artist: "Daft Punk",
                 score: 100
               }
               | _
             ] = recordings
    end
  end

  describe "get_recording/1" do
    test "returns full recording details with ISRCs and releases" do
      ApiMock.expect(
        MusicBrainzApi,
        path: {:get, "/ws/2/recording/60fa767a-d85d-4991-82bc-4294e0b11ae7"},
        headers: [{"user-agent", "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "musicbrainz_api/recordings/get_recording/response.json",
        status: 200
      )

      {:ok, recording} = MusicBrainzApi.get_recording("60fa767a-d85d-4991-82bc-4294e0b11ae7")

      assert %{
               mbid: "60fa767a-d85d-4991-82bc-4294e0b11ae7",
               title: "One More Time",
               artist: "Daft Punk",
               duration_ms: 320_840,
               first_release_date: "2000",
               isrcs: ["GBAHT1305744", "GBDUW0000053"]
             } = recording

      assert length(recording.releases) > 0

      assert Enum.any?(recording.releases, fn r ->
               r.title == "Discovery" and r.status == "Official"
             end)
    end
  end
end
