defmodule PremiereEcoute.Apis.Lyrics.GeniusApi.SearchTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Lyrics.GeniusApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_song/1" do
    test "returns song results for a query" do
      ApiMock.expect(
        GeniusApi,
        path: {:get, "/search"},
        headers: [{"content-type", "application/json"}],
        response: "genius_api/search/search_song/response.json",
        status: 200
      )

      {:ok, songs} = GeniusApi.search_song("Daft Punk One More Time")

      assert [
               %{
                 id: 71_255,
                 title: "One More Time",
                 artist: "Daft Punk",
                 url: "https://genius.com/Daft-punk-one-more-time-lyrics",
                 thumbnail_url: "https://images.genius.com/4990083e3eacb207d17fc04ece010e1f.300x300x1.png",
                 release_date: "November 13, 2000"
               }
               | _
             ] = songs
    end
  end
end
