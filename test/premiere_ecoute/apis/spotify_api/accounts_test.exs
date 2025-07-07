defmodule PremiereEcoute.Apis.SpotifyApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.SpotifyApi

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
end
