defmodule PremiereEcoute.Apis.Video.YoutubeApi.SearchTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Video.YoutubeApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_track_videos/1" do
    test "returns video results for a track query" do
      ApiMock.expect(
        YoutubeApi,
        path: {:get, "/youtube/v3/search"},
        headers: [{"content-type", "application/json"}],
        response: "youtube_api/videos/search_videos/response.json",
        status: 200
      )

      {:ok, videos} = YoutubeApi.search_track_videos("Daft Punk One More Time")

      assert length(videos) == 10

      assert [
               %{
                 id: "FGBhQbmPwH8",
                 url: "https://www.youtube.com/watch?v=FGBhQbmPwH8",
                 title: "Daft Punk - One More Time (Official Video)",
                 channel_title: "Daft Punk",
                 thumbnail_url: "https://i.ytimg.com/vi/FGBhQbmPwH8/hqdefault.jpg"
               }
               | _
             ] = videos
    end
  end
end
