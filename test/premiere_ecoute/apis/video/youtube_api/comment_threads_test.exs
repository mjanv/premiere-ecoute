defmodule PremiereEcoute.Apis.Video.YoutubeApi.CommentThreadsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Video.YoutubeApi

  setup {Req.Test, :verify_on_exit!}

  describe "get_comment_threads/1" do
    test "returns top-level comments for a video" do
      ApiMock.expect(
        YoutubeApi,
        path: {:get, "/youtube/v3/commentThreads"},
        headers: [{"content-type", "application/json"}],
        response: "youtube_api/comment_threads/get_comment_threads/response.json",
        status: 200
      )

      {:ok, comments} = YoutubeApi.get_comment_threads("fWxv_yPImZ4")

      assert length(comments) == 5

      assert [
               %{
                 id: "UgyfGqFzG22pp7sw7OV4AaABAg",
                 author: "@bleuapart",
                 published_at: "2026-03-18T14:33:27Z",
                 total_reply_count: 0
               }
               | _
             ] = comments
    end
  end
end
