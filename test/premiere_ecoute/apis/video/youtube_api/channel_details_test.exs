defmodule PremiereEcoute.Apis.Video.YoutubeApi.ChannelDetailsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Video.YoutubeApi

  setup {Req.Test, :verify_on_exit!}

  describe "get_channel/1" do
    test "returns channel details" do
      ApiMock.expect(
        YoutubeApi,
        path: {:get, "/youtube/v3/channels"},
        headers: [{"content-type", "application/json"}],
        response: "youtube_api/channels/get_channel/response.json",
        status: 200
      )

      {:ok, channel} = YoutubeApi.get_channel("UCsmECZ1G4vHMSmH-m6cJBWA")

      assert %{
               id: "UCsmECZ1G4vHMSmH-m6cJBWA",
               title: "Flonflon",
               custom_url: "@flonflon",
               country: "FR",
               uploads_playlist_id: "UUsmECZ1G4vHMSmH-m6cJBWA"
             } = channel

      assert channel.subscriber_count > 0
      assert channel.video_count > 0
      assert channel.view_count > 0
    end
  end
end
