defmodule PremiereEcoute.Apis.TidalApi.PlaylistsTest do
  use PremiereEcoute.DataCase

  # alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TidalApi

  # alias PremiereEcoute.Discography.Playlist
  # alias PremiereEcoute.Discography.Playlist.Track

  describe "get_playlist/1" do
    @tag :skip
    test "get a playlist from an unique identifier" do
      # ApiMock.expect(
      #   TidalApi,
      #   path: {:get, "/playlist/eaaa8f2b-b891-466d-828b-879891adf264"},
      #   headers: [{"content-type", "application/json"}],
      #   response: "tidal_api/playlists/get_playlist/response.json",
      #   status: 200
      # )

      id = "eaaa8f2b-b891-466d-828b-879891adf264"

      {:ok, _playlist} = TidalApi.get_playlist(id)
    end
  end
end
