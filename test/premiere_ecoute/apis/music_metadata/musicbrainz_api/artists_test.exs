defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi.ArtistsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_artists/1" do
    test "returns artist results for a query" do
      ApiMock.expect(
        MusicBrainzApi,
        path: {:get, "/ws/2/artist"},
        headers: [{"user-agent", "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "musicbrainz_api/artists/search_artists/response.json",
        status: 200
      )

      {:ok, artists} = MusicBrainzApi.search_artists(~s(artist:"Daft Punk"))

      assert [
               %{
                 mbid: "056e4f3e-d505-4dad-8ec1-d04f521cbb56",
                 name: "Daft Punk",
                 type: "Group",
                 country: "FR",
                 disambiguation: "French electronic duo",
                 score: 100
               }
               | _
             ] = artists
    end
  end

  describe "get_artist/1" do
    test "returns full artist details with release groups" do
      ApiMock.expect(
        MusicBrainzApi,
        path: {:get, "/ws/2/artist/056e4f3e-d505-4dad-8ec1-d04f521cbb56"},
        headers: [{"user-agent", "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "musicbrainz_api/artists/get_artist/response.json",
        status: 200
      )

      {:ok, artist} = MusicBrainzApi.get_artist("056e4f3e-d505-4dad-8ec1-d04f521cbb56")

      assert %{
               mbid: "056e4f3e-d505-4dad-8ec1-d04f521cbb56",
               name: "Daft Punk",
               type: "Group",
               country: "FR",
               disambiguation: "French electronic duo",
               begin_area: "Paris",
               life_span: %{begin: "1993", end: "2021-02-22", ended: true}
             } = artist

      assert length(artist.release_groups) == 25

      assert Enum.any?(artist.release_groups, fn rg ->
               rg.title == "Discovery" and rg.primary_type == "Album"
             end)
    end
  end
end
