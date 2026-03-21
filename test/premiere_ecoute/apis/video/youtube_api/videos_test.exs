defmodule PremiereEcoute.Apis.Video.YoutubeApi.VideosTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Video.YoutubeApi

  setup {Req.Test, :verify_on_exit!}

  describe "get_video/1" do
    test "returns full video details" do
      ApiMock.expect(
        YoutubeApi,
        path: {:get, "/youtube/v3/videos"},
        headers: [{"content-type", "application/json"}],
        response: "youtube_api/videos/get_video/response.json",
        status: 200
      )

      {:ok, video} = YoutubeApi.get_video("fWxv_yPImZ4")

      assert %{
               id: "fWxv_yPImZ4",
               title: "PREMIÈRE ÉCOUTE : \"Feel So Good Around U\" de LB aka LABAT (React Live)",
               published_at: "2026-03-17T16:30:17Z",
               thumbnail_url: "https://i.ytimg.com/vi/fWxv_yPImZ4/maxresdefault.jpg",
               duration: "PT54M1S",
               view_count: 225,
               like_count: 13,
               comment_count: 6
             } = video

      assert "musique" in video.tags
    end
  end
end
