defmodule PremiereEcoute.Apis.Video.YoutubeApi.ChannelsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Video

  setup {Req.Test, :verify_on_exit!}

  @channel_id "UCsmECZ1G4vHMSmH-m6cJBWA"
  @uploads_playlist_id "UUsmECZ1G4vHMSmH-m6cJBWA"
  @path "/youtube/v3/playlistItems"

  defp expect_page(fixture, assertions \\ fn _conn -> :ok end) do
    Req.Test.expect(YoutubeApi, fn conn ->
      assertions.(conn)

      ApiMock.fun(conn,
        path: {:get, @path},
        response: "youtube_api/channels/get_channel_videos/#{fixture}",
        status: 200
      )
    end)
  end

  describe "get_channel_videos/1" do
    test "lists the videos of the channel uploads playlist" do
      expect_page("response_page_2.json", fn conn ->
        assert conn.query_params["playlistId"] == @uploads_playlist_id
        assert conn.query_params["part"] == "snippet,contentDetails,status"
        assert conn.query_params["maxResults"] == "50"
      end)

      {:ok, videos} = YoutubeApi.get_channel_videos(@channel_id)

      assert [
               %Video{
                 id: "fWxv_yPImZ4",
                 url: "https://www.youtube.com/watch?v=fWxv_yPImZ4",
                 title: "Café Elixir #1 - Les microservice à l'époque d'Elixir",
                 channel_id: @channel_id,
                 channel_title: "Flonflon",
                 published_at: "2026-03-10T16:30:17Z",
                 privacy: :unlisted,
                 thumbnail_url: "https://i.ytimg.com/vi/fWxv_yPImZ4/hqdefault.jpg"
               },
               %Video{id: "OldVideo0001", privacy: :public}
             ] = videos
    end

    test "keeps the description and the video publication date" do
      expect_page("response.json")
      expect_page("response_page_2.json")

      {:ok, [first, second | _]} = YoutubeApi.get_channel_videos(@channel_id)

      assert first.id == "DGyTFnNB_UM"
      assert first.description =~ "/sessions/flon/abc123"
      assert first.published_at == "2026-03-18T16:30:06Z"
      assert %Video{id: "PrivVid0001", privacy: :private} = second
    end

    test "follows the next page token" do
      expect_page("response.json", fn conn -> refute Map.has_key?(conn.query_params, "pageToken") end)
      expect_page("response_page_2.json", fn conn -> assert conn.query_params["pageToken"] == "PAGE2" end)

      {:ok, videos} = YoutubeApi.get_channel_videos(@channel_id)

      assert Enum.map(videos, & &1.id) == ["DGyTFnNB_UM", "PrivVid0001", "fWxv_yPImZ4", "OldVideo0001"]
    end

    test "stops after 3 pages" do
      Req.Test.expect(YoutubeApi, 3, fn conn ->
        ApiMock.fun(conn, path: {:get, @path}, response: "youtube_api/channels/get_channel_videos/response.json", status: 200)
      end)

      {:ok, videos} = YoutubeApi.get_channel_videos(@channel_id)

      assert length(videos) == 6
    end

    test "stops paging and drops videos published before the given date" do
      expect_page("response.json")

      {:ok, videos} = YoutubeApi.get_channel_videos(@channel_id, since: ~U[2026-03-18 00:00:00Z])

      assert Enum.map(videos, & &1.id) == ["DGyTFnNB_UM"]
    end

    test "keeps paging while videos are newer than the given date" do
      expect_page("response.json")
      expect_page("response_page_2.json")

      {:ok, videos} = YoutubeApi.get_channel_videos(@channel_id, since: ~U[2026-03-01 00:00:00Z])

      assert Enum.map(videos, & &1.id) == ["DGyTFnNB_UM", "PrivVid0001", "fWxv_yPImZ4"]
    end

    test "returns an error on an unexpected status" do
      ApiMock.expect(YoutubeApi, path: {:get, @path}, body: %{"error" => %{"code" => 403}}, status: 403)

      assert {:error, _} = YoutubeApi.get_channel_videos(@channel_id)
    end

    test "rejects ids that are not YouTube channel ids" do
      assert {:error, :invalid_channel_id} = YoutubeApi.get_channel_videos("@handle")
    end
  end
end
