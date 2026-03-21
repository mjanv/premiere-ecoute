defmodule PremiereEcoute.Apis.MusicMetadata.GeniusApi.SongsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi

  setup {Req.Test, :verify_on_exit!}

  describe "get_song/1" do
    test "returns full song details" do
      ApiMock.expect(
        GeniusApi,
        path: {:get, "/songs/71255"},
        headers: [{"content-type", "application/json"}],
        response: "genius_api/songs/get_song/response.json",
        status: 200
      )

      {:ok, song} = GeniusApi.get_song(71_255)

      assert %{
               id: 71_255,
               title: "One More Time",
               full_title: "One More Time by\u00a0Daft\u00a0Punk (Ft.\u00a0Romanthony)",
               artist: "Daft Punk (Ft. Romanthony)",
               url: "https://genius.com/Daft-punk-one-more-time-lyrics",
               path: "/Daft-punk-one-more-time-lyrics",
               release_date: "2000-11-13",
               language: "en",
               image_url: "https://images.genius.com/4990083e3eacb207d17fc04ece010e1f.1000x1000x1.png",
               annotation_count: 3,
               pyongs_count: 44,
               lyrics_state: "complete",
               lyrics_marked_complete_by: nil,
               lyrics_marked_staff_approved_by: nil,
               translations: [
                 %{
                   id: 11_620_947,
                   language: "pl",
                   title: "Daft Punk - One More Time (polskie tłumaczenie)",
                   url: "https://genius.com/Polskie-tumaczenia-genius-daft-punk-one-more-time-polskie-tumaczenie-lyrics"
                 }
               ],
               primary_artist: %{
                 id: 13_585,
                 name: "Daft Punk",
                 url: "https://genius.com/artists/Daft-punk"
               }
             } = song

      assert song.pageviews > 0
    end
  end
end
