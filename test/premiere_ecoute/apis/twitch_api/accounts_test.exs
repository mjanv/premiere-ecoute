defmodule PremiereEcoute.Apis.TwitchApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.TwitchApi

  describe "authorization_url/0" do
    test "can generate a valid authorization url for Twitch login" do
      url = TwitchApi.Accounts.authorization_url(nil, "state")

      assert url =~
               "https://id.twitch.tv/oauth2/authorize?scope=channel%3Amanage%3Apolls+channel%3Aread%3Apolls+channel%3Abot+user%3Aread%3Aemail+user%3Aread%3Achat+user%3Awrite%3Achat+user%3Abot+moderator%3Amanage%3Aannouncements"

      assert url =~ "response_type=code"
      assert url =~ "client_id="
      assert url =~ "redirect_uri="
      assert url =~ "state=state"
    end
  end
end
