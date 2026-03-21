defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.SearchTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_artist/1" do
    test "returns page results for an artist name" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/w/api.php"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/search/search_artist/response.json",
        status: 200
      )

      {:ok, results} = WikipediaApi.search_artist("Daft Punk")

      assert [
               %{
                 page_id: 168_310,
                 title: "Daft Punk",
                 url: "https://en.wikipedia.org/wiki/Daft%20Punk"
               }
               | _
             ] = results

      assert length(results) == 5
    end
  end

  describe "search_album/2" do
    test "returns page results for an album title and artist" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/w/api.php"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/search/search_album/response.json",
        status: 200
      )

      {:ok, results} = WikipediaApi.search_album("Random Access Memories", "Daft Punk")

      assert [
               %{
                 page_id: 38_898_753,
                 title: "Random Access Memories",
                 url: "https://en.wikipedia.org/wiki/Random%20Access%20Memories"
               }
               | _
             ] = results

      assert length(results) == 5
    end
  end
end
