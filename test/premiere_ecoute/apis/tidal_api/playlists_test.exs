defmodule PremiereEcoute.Apis.TidalApi.PlaylistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TidalApi

  alias PremiereEcoute.Discography.Playlist

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  describe "get_playlist/1" do
    test "can get a playlist from a unique identifier" do
      client_id = Application.get_env(:premiere_ecoute, :tidal_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :tidal_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      # Mock the client_credentials call first
      ApiMock.expect(
        TidalApi,
        path: {:post, "/v1/oauth2/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "tidal_api/accounts/client_credentials/response.json",
        status: 200
      )

      # Mock the playlist GET request
      ApiMock.expect(
        TidalApi,
        path: {:get, "/v2/playlists/eaaa8f2b-b891-466d-828b-879891adf264"},
        headers: [
          {"authorization", "Bearer xHhiYE85rkDfPt7wLOyq3MqN2gKmB9n5WvJcP3sA"},
          {"content-type", "application/json"}
        ],
        params: %{"countryCode" => "FR", "include" => "coverArt,items"},
        response: "tidal_api/playlists/get_playlist/response.json",
        status: 200
      )

      id = "eaaa8f2b-b891-466d-828b-879891adf264"

      {:ok, playlist} = TidalApi.get_playlist(id)

      assert %Playlist{
               provider: :tidal,
               playlist_id: "eaaa8f2b-b891-466d-828b-879891adf264",
               title: "Je suis en Juillet",
               tracks: tracks
             } = playlist

      # Verify that tracks are track IDs as strings (as per the current implementation)
      assert is_list(tracks)
      # Number of tracks in the response data
      assert length(tracks) == 20

      # Check that track IDs are extracted correctly
      assert "77690190" in tracks
      assert "87332850" in tracks
      assert "85905133" in tracks
    end

    test "handles API error responses" do
      client_id = Application.get_env(:premiere_ecoute, :tidal_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :tidal_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      # Mock successful client_credentials
      ApiMock.expect(
        TidalApi,
        path: {:post, "/v1/oauth2/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "tidal_api/accounts/client_credentials/response.json",
        status: 200
      )

      # Mock failed playlist request
      ApiMock.expect(
        TidalApi,
        path: {:get, "/v2/playlists/non-existent-playlist"},
        headers: [
          {"authorization", "Bearer xHhiYE85rkDfPt7wLOyq3MqN2gKmB9n5WvJcP3sA"},
          {"content-type", "application/json"}
        ],
        params: %{"countryCode" => "FR", "include" => "coverArt,items"},
        response: %{"errors" => [%{"title" => "Not Found", "status" => 404}]},
        status: 404
      )

      {:error, _error} = TidalApi.get_playlist("non-existent-playlist")
    end
  end
end
