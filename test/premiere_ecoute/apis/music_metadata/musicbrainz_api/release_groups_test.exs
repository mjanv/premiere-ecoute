defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi.ReleaseGroupsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_release_groups/1" do
    test "returns release-group results for a query" do
      ApiMock.expect(
        MusicBrainzApi,
        path: {:get, "/ws/2/release-group"},
        headers: [{"user-agent", "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "musicbrainz_api/release_groups/search_release_groups/response.json",
        status: 200
      )

      {:ok, groups} = MusicBrainzApi.search_release_groups(~s(releasegroup:"Discovery" AND artist:"Daft Punk"))

      assert [
               %{
                 mbid: "48117b90-a16e-34ca-a514-19c702df1158",
                 title: "Discovery",
                 artist: "Daft Punk",
                 primary_type: "Album",
                 first_release_date: "2001-02-26",
                 score: 100
               }
               | _
             ] = groups
    end
  end

  describe "get_release_group/1" do
    test "returns full release-group details with releases" do
      ApiMock.expect(
        MusicBrainzApi,
        path: {:get, "/ws/2/release-group/48117b90-a16e-34ca-a514-19c702df1158"},
        headers: [{"user-agent", "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "musicbrainz_api/release_groups/get_release_group/response.json",
        status: 200
      )

      {:ok, group} = MusicBrainzApi.get_release_group("48117b90-a16e-34ca-a514-19c702df1158")

      assert %{
               mbid: "48117b90-a16e-34ca-a514-19c702df1158",
               title: "Discovery",
               artist: "Daft Punk",
               primary_type: "Album",
               first_release_date: "2001-02-26"
             } = group

      assert length(group.releases) == 24

      assert Enum.any?(group.releases, fn r ->
               r.date == "2001-02-26" and r.status == "Official"
             end)
    end
  end
end
