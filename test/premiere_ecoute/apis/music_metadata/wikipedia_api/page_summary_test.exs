defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageSummaryTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Summary

  setup {Req.Test, :verify_on_exit!}

  describe "summary/1" do
    test "returns summary for an artist page" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/api/rest_v1/page/summary/Daft%20Punk"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/page_summary/summary_artist/response.json",
        status: 200
      )

      {:ok, summary} = WikipediaApi.summary(%Page{id: 168_310, title: "Daft Punk"})

      assert %Summary{
               title: "Daft Punk",
               thumbnail_url:
                 "https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Daft_Punk_in_2013_2-_centered.jpg/330px-Daft_Punk_in_2013_2-_centered.jpg",
               page_url: "https://en.wikipedia.org/wiki/Daft_Punk"
             } = summary

      assert String.contains?(summary.extract, "French electronic music duo")
    end

    test "returns summary for an album page" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/api/rest_v1/page/summary/Random%20Access%20Memories"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/page_summary/summary_album/response.json",
        status: 200
      )

      {:ok, summary} = WikipediaApi.summary(%Page{id: 38_898_753, title: "Random Access Memories"})

      assert %Summary{
               title: "Random Access Memories",
               thumbnail_url: "https://upload.wikimedia.org/wikipedia/en/2/26/Daft_Punk_-_Random_Access_Memories.png",
               page_url: "https://en.wikipedia.org/wiki/Random_Access_Memories"
             } = summary

      assert String.contains?(summary.extract, "Daft Punk")
    end
  end
end
