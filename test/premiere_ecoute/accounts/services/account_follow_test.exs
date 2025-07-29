defmodule PremiereEcoute.Accounts.Services.AccountFollowTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User.Follow

  alias PremiereEcoute.Apis.TwitchApi.Mock, as: TwitchApi

  describe "follow_streamer/1" do
    test "add the followed at information to a follow" do
      %{id: user_id} = user = user_fixture()
      scope = user_scope_fixture(user)
      %{id: streamer_id} = streamer = user_fixture(%{role: :streamer})

      expect(TwitchApi, :get_followed_channel, fn %Scope{user: ^user}, ^streamer ->
        payload = %{
          "broadcaster_id" => streamer.twitch_user_id,
          "broadcaster_login" => "basketweaver101",
          "broadcaster_name" => "BasketWeaver101",
          "followed_at" => "2022-05-24T22:22:08Z"
        }

        {:ok, payload}
      end)

      {:ok, follow} = Accounts.follow_streamer(scope, streamer)

      assert %Follow{user_id: ^user_id, streamer_id: ^streamer_id, followed_at: ~N[2022-05-24 22:22:08]} = follow
    end

    test "add no followed at information to a follow" do
      %{id: user_id} = user = user_fixture()
      scope = user_scope_fixture(user)
      %{id: streamer_id} = streamer = user_fixture(%{role: :streamer})

      expect(TwitchApi, :get_followed_channel, fn %Scope{user: ^user}, ^streamer -> {:ok, %{"data" => []}} end)

      {:ok, follow} = Accounts.follow_streamer(scope, streamer)

      assert %Follow{user_id: ^user_id, streamer_id: ^streamer_id, followed_at: nil} = follow
    end
  end
end
