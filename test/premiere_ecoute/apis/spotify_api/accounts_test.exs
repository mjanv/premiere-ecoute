defmodule PremiereEcoute.Apis.SpotifyApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.SpotifyApi

  @moduletag :spotify

  describe "authorization_url/0" do
    test "can generate a valid authorization url for Spotify login" do
      url = SpotifyApi.Accounts.authorization_url()

      assert url =~
               "https://accounts.spotify.com/authorize?scope=user-read-private+user-read-email"

      assert url =~ "response_type=code"
      assert url =~ "client_id="
      assert url =~ "redirect_uri="
      assert url =~ "state="
    end
  end

  describe "authorization_code/2" do
    @tag :skip
    test "can request an access token from callback code" do
      code =
        "AQCAMeQFIegwMbatXUeygxruCL5nYyrlqGAIdA2UKc7-6nQ_Hnd7Hxkx8P713mvkhjEQX80waN-czFSJ5vtcZZGtSM5pfmWezsB_vQmvMa1BiVvuUTG8pZVvXdzRbg6lF-gdl3t-jVr7G4grLnoTKCOiUiCXUKC10hjcUpacY8T3h0w8FFuFg3sndEjkC-HQug6KSYydt25zdsEo3d7fAFtoxE4dxz6wIC11I9klrXsFSFU"

      state = "D_ayTEZidSgslmZ8"

      {:ok, %{access_token: access_token, refresh_token: refresh_token, expires_in: expires_in}} =
        SpotifyApi.Accounts.authorization_code(code, state)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert expires_in == 3600
    end
  end
end
