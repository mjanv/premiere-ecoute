defmodule PremiereEcoute.Apis.Streaming.TwitchApi.RewardsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Twitch.Redemption
  alias PremiereEcoute.Twitch.Reward

  setup {Req.Test, :verify_on_exit!}

  setup do
    scope =
      user_scope_fixture(
        user_fixture(%{
          twitch: %{user_id: "274637212", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
        })
      )

    {:ok, %{scope: scope}}
  end

  describe "create_reward/2" do
    test "creates a reward and returns a Reward struct", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/channel_points/custom_rewards"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/rewards/create_custom_rewards/request.json",
        response: "twitch_api/rewards/create_custom_rewards/response.json",
        status: 200
      )

      {:ok, reward} = TwitchApi.create_reward(scope, %{title: "game analysis 1v1", cost: 50_000})

      assert reward == %Reward{
               id: "afaa7e34-6b17-49f0-a19a-d1e76eaaf673",
               broadcaster_id: "274637212",
               title: "game analysis 1v1",
               cost: 50_000,
               prompt: "",
               is_enabled: true,
               is_paused: false,
               is_in_stock: true,
               is_user_input_required: false
             }
    end
  end

  describe "get_rewards/1" do
    test "returns a list of Reward structs", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/channel_points/custom_rewards"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/rewards/get_custom_reward/response.json",
        status: 200
      )

      {:ok, rewards} = TwitchApi.get_rewards(scope)

      assert rewards == [
               %Reward{
                 id: "92af127c-7326-4483-a52b-b0da0be61c01",
                 broadcaster_id: "274637212",
                 title: "game analysis",
                 cost: 50_000,
                 prompt: "",
                 is_enabled: true,
                 is_paused: false,
                 is_in_stock: true,
                 is_user_input_required: false
               }
             ]
    end
  end

  describe "update_reward/3" do
    test "updates a reward and returns the updated Reward struct", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:patch, "/helix/channel_points/custom_rewards"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/rewards/update_custom_reward/response.json",
        status: 200
      )

      {:ok, reward} =
        TwitchApi.update_reward(scope, "92af127c-7326-4483-a52b-b0da0be61c01", %{
          title: "game analysis 2v2",
          cost: 30_000,
          is_enabled: false
        })

      assert reward == %Reward{
               id: "92af127c-7326-4483-a52b-b0da0be61c01",
               broadcaster_id: "274637212",
               title: "game analysis 2v2",
               cost: 30_000,
               prompt: "",
               is_enabled: false,
               is_paused: false,
               is_in_stock: false,
               is_user_input_required: false
             }
    end
  end

  describe "delete_reward/2" do
    test "deletes a reward and returns :ok", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/channel_points/custom_rewards"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: nil,
        status: 204
      )

      assert :ok = TwitchApi.delete_reward(scope, "92af127c-7326-4483-a52b-b0da0be61c01")
    end
  end

  describe "get_redemptions/3" do
    test "returns a list of Redemption structs", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/channel_points/custom_rewards/redemptions"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/rewards/get_custom_reward_redemption/response.json",
        status: 200
      )

      {:ok, redemptions} =
        TwitchApi.get_redemptions(scope, "92af127c-7326-4483-a52b-b0da0be61c01", :unfulfilled)

      assert redemptions == [
               %Redemption{
                 id: "17fa2df1-ad76-4804-bfa5-a40ef63efe63",
                 broadcaster_id: "274637212",
                 user_id: "274637212",
                 user_login: "torpedo09",
                 reward_id: "92af127c-7326-4483-a52b-b0da0be61c01",
                 reward_title: "game analysis",
                 user_input: "",
                 status: :canceled,
                 redeemed_at: "2020-07-01T18:37:32Z"
               }
             ]
    end
  end

  describe "update_redemption_status/4" do
    test "updates redemption status and returns updated Redemption struct", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:patch, "/helix/channel_points/custom_rewards/redemptions"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/rewards/update_redemption_status/response.json",
        status: 200
      )

      {:ok, redemption} =
        TwitchApi.update_redemption_status(
          scope,
          "92af127c-7326-4483-a52b-b0da0be61c01",
          "17fa2df1-ad76-4804-bfa5-a40ef63efe63",
          :canceled
        )

      assert redemption == %Redemption{
               id: "17fa2df1-ad76-4804-bfa5-a40ef63efe63",
               broadcaster_id: "274637212",
               user_id: "274637212",
               user_login: "torpedo09",
               reward_id: "92af127c-7326-4483-a52b-b0da0be61c01",
               reward_title: "game analysis",
               user_input: "",
               status: :canceled,
               redeemed_at: "2020-07-01T18:37:32Z"
             }
    end
  end
end
