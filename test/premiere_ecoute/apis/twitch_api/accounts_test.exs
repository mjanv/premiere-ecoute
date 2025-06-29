defmodule PremiereEcoute.Apis.TwitchApi.AccountsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.TwitchApi.Accounts

  @code "185m5pecjunyfvxte8sxv6s4x7ynh3"

  @tag :skip
  test "?" do
    {:ok, user} = Accounts.authorization_code(@code)

    %{
      user_id: user_id,
      username: username,
      access_token: access_token,
      refresh_token: refresh_token,
      display_name: display_name
    } = user

    assert user_id == "441903922"
    assert username == "lanfeust313"
    assert display_name == "Lanfeust313"
    assert is_binary(access_token)
    assert is_binary(refresh_token)
  end
end
