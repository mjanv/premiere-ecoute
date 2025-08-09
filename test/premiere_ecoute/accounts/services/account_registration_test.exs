defmodule PremiereEcoute.Accounts.Services.AccountRegistrationTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Services.AccountRegistration
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.OauthToken
  alias PremiereEcoute.Apis.TwitchApi.Mock, as: TwitchApi
  alias PremiereEcoute.Events.AccountAssociated
  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Events.Store

  defp twitch_data do
    %{
      user_id: "441903922",
      email: "username+twitch@yahoo.fr",
      access_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      refresh_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      expires_in: 3600,
      username: "user1004",
      display_name: "User1004",
      broadcaster_type: "affiliate"
    }
  end

  defp spotify_data do
    %{
      user_id: "username007",
      email: "username+spotify@yahoo.fr",
      username: "Username",
      country: "FR",
      product: "premium",
      access_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      refresh_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      expires_in: 3600
    }
  end

  setup do
    stub(TwitchApi, :get_followed_channel, fn _, _ -> {:ok, nil} end)

    :ok
  end

  describe "register_twitch_user/1" do
    test "create a new user" do
      data = twitch_data()
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      assert %User{
               email: "username+twitch@yahoo.fr",
               role: :streamer,
               twitch: %OauthToken{
                 user_id: "441903922",
                 access_token: access_token,
                 refresh_token: refresh_token
               }
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token

      events = Store.read("user-#{user.id}")
      assert events == [%AccountCreated{id: user.id}, %AccountAssociated{id: user.id, provider: "twitch", user_id: "441903922"}]
    end

    test "create a new user with a default email address" do
      data = Map.merge(twitch_data(), %{email: ""})
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      assert %User{
               email: "user1004@twitch.tv",
               role: :streamer,
               twitch: %OauthToken{
                 user_id: "441903922",
                 access_token: access_token,
                 refresh_token: refresh_token
               }
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token

      events = Store.read("user-#{user.id}")
      assert events == [%AccountCreated{id: user.id}, %AccountAssociated{id: user.id, provider: "twitch", user_id: "441903922"}]
    end

    test "find an existing user" do
      data = twitch_data()
      {:ok, _} = AccountRegistration.register_twitch_user(data)

      data = twitch_data()
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      assert %User{
               email: "username+twitch@yahoo.fr",
               role: :streamer,
               twitch: %OauthToken{
                 user_id: "441903922",
                 access_token: access_token,
                 refresh_token: refresh_token
               }
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token

      events = Store.read("user-#{user.id}")
      assert events == [%AccountCreated{id: user.id}, %AccountAssociated{id: user.id, provider: "twitch", user_id: "441903922"}]
    end
  end

  describe "register_spotify_user/2" do
    test "update an existing user with a default address" do
      data = Map.merge(twitch_data(), %{email: ""})
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      data = spotify_data()
      {:ok, user} = AccountRegistration.register_spotify_user(data, user.id)

      assert %User{
               email: "user1004@twitch.tv",
               spotify: %OauthToken{
                 user_id: "username007",
                 username: "Username",
                 access_token: access_token,
                 refresh_token: refresh_token
               }
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token
    end

    test "update an existing user" do
      data = twitch_data()
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      data = spotify_data()
      {:ok, user} = AccountRegistration.register_spotify_user(data, user.id)

      assert %User{
               email: "username+twitch@yahoo.fr",
               spotify: %OauthToken{
                 user_id: "username007",
                 username: "Username",
                 access_token: access_token,
                 refresh_token: refresh_token
               }
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token
    end
  end
end
