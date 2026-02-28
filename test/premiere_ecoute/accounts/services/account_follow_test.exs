defmodule PremiereEcoute.Accounts.Services.AccountFollowTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow

  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  describe "follow_streamer/2" do
    test "add the followed at information to a follow" do
      %{id: user_id} =
        user = user_fixture(%{role: :viewer, twitch: %{user_id: unique_user_id()}, spotify: %{user_id: unique_user_id()}})

      scope = user_scope_fixture(user)

      %{id: streamer_id} =
        streamer = user_fixture(%{role: :streamer, twitch: %{user_id: unique_user_id()}, spotify: %{user_id: unique_user_id()}})

      expect(TwitchApi, :get_followed_channel, fn %Scope{user: ^user}, ^streamer ->
        payload = %{
          "broadcaster_id" => streamer.twitch.user_id,
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

  describe "follow_streamers/1" do
    test "automatically follows all followed streamers" do
      %{id: user_id} = user = user_fixture()
      scope = user_scope_fixture(user)
      %{id: streamer1_id} = streamer1 = user_fixture(%{role: :streamer, twitch: %{user_id: "test_1"}})
      %{id: streamer2_id} = user_fixture(%{role: :streamer, twitch: %{user_id: "test_2"}})

      stub(TwitchApi, :get_followed_channel, fn %Scope{user: %{id: ^user_id}}, streamer ->
        case streamer.twitch.user_id do
          "test_1" ->
            payload = %{
              "broadcaster_id" => streamer1.twitch.user_id,
              "broadcaster_login" => "basketweaver101",
              "broadcaster_name" => "BasketWeaver101",
              "followed_at" => "2022-05-24T22:22:08Z"
            }

            {:ok, payload}

          "test_2" ->
            {:ok, %{"data" => []}}

          _ ->
            # Handle seed streamers - return no follow info
            {:ok, %{"data" => []}}
        end
      end)

      :ok = Accounts.follow_streamers(scope)

      user = Accounts.get_user!(user_id)

      assert [%User{id: ^streamer1_id}] = user.channels
      refute streamer2_id in Enum.map(user.channels, fn user -> user.id end)
    end
  end
end
