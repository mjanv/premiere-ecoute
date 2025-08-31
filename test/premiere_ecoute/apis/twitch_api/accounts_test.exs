defmodule PremiereEcoute.Apis.TwitchApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.TwitchApi

  describe "authorization_url/0" do
    test "can generate a valid authorization url for Twitch login" do
      url = TwitchApi.Accounts.authorization_url(nil, "state")

      assert url =~ "https://id.twitch.tv/oauth2/authorize?scope=user%3Aread%3Aemail+user%3Aread%3Afollows"
      assert url =~ "response_type=code"
      assert url =~ "client_id="
      assert url =~ "redirect_uri="
      assert url =~ "state=state"
    end
  end
end
