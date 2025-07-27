defmodule PremiereEcoute.Accounts.Services.AccountRegistrationTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Services.AccountRegistration
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.EventStore

  defp twitch_data do
    %{
      user_id: "441903922",
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
      access_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      refresh_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
      expires_in: 3600
    }
  end

  describe "register_twitch_user/1" do
    test "create a new user" do
      data = twitch_data()
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      assert %User{
               email: "user1004@twitch.tv",
               role: :streamer,
               twitch_user_id: "441903922",
               twitch_access_token: access_token,
               twitch_refresh_token: refresh_token
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token

      events = EventStore.read("user-#{user.id}")
      assert events == [%AccountCreated{id: "#{user.id}", twitch_user_id: "441903922"}]
    end

    test "find an existing user" do
      data = twitch_data()
      {:ok, _} = AccountRegistration.register_twitch_user(data)

      data = twitch_data()
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      assert %User{
               email: "user1004@twitch.tv",
               role: :streamer,
               twitch_user_id: "441903922",
               twitch_access_token: access_token,
               twitch_refresh_token: refresh_token
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token

      events = EventStore.read("user-#{user.id}")
      assert events == [%AccountCreated{id: "#{user.id}", twitch_user_id: "441903922"}]
    end
  end

  describe "register_spotify_user/2" do
    test "update an existing user" do
      data = twitch_data()
      {:ok, user} = AccountRegistration.register_twitch_user(data)

      data = spotify_data()
      {:ok, user} = AccountRegistration.register_spotify_user(data, user.id)

      assert %User{
               email: "user1004@twitch.tv",
               role: :streamer,
               twitch_user_id: "441903922",
               spotify_access_token: access_token,
               spotify_refresh_token: refresh_token
             } = user

      assert data[:access_token] == access_token
      assert data[:refresh_token] == refresh_token
    end
  end
end
