defmodule PremiereEcoute.Apis.Video.YoutubeApi.ChannelsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Video.YoutubeApi

  setup {Req.Test, :verify_on_exit!}

  describe "get_channel_videos/1" do
    test "returns a list of videos for a channel" do
      ApiMock.expect(
        YoutubeApi,
        path: {:get, "/youtube/v3/search"},
        headers: [{"content-type", "application/json"}],
        response: "youtube_api/channels/get_channel_videos/response.json",
        status: 200
      )

      channel_id = "UCsmECZ1G4vHMSmH-m6cJBWA"

      {:ok, videos} = YoutubeApi.get_channel_videos(channel_id)

      assert length(videos) == 50

      assert [
               %{
                 id: "DGyTFnNB_UM",
                 title: "Elle va accorder sa guitare ?? React DREAMS : 1 R\u00CAVE, 2 VIES - \u00C9pisodes 9 et 10 [Replay Live]",
                 published_at: "2026-03-18T16:30:06Z",
                 thumbnail_url: "https://i.ytimg.com/vi/DGyTFnNB_UM/hqdefault.jpg"
               }
               | _
             ] = videos
    end
  end
end
