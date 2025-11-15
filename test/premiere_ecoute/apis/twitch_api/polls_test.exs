defmodule PremiereEcoute.Apis.TwitchApi.PollsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    scope =
      user_scope_fixture(
        user_fixture(%{
          twitch: %{user_id: "141981764", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
        })
      )

    {:ok, %{scope: scope}}
  end

  describe "create_poll/2" do
    test "can create a new poll", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/polls"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/polls/create_poll/request.json",
        response: "twitch_api/polls/create_poll/response.json",
        status: 200
      )

      poll = %{title: "Heads or Tails?", choices: ["Heads", "Tails"], duration: 1800}

      {:ok, poll} = TwitchApi.create_poll(scope, poll)

      assert poll == %{
               "bits_per_vote" => 0,
               "bits_voting_enabled" => false,
               "broadcaster_id" => "141981764",
               "broadcaster_login" => "twitchdev",
               "broadcaster_name" => "TwitchDev",
               "channel_points_voting_enabled" => false,
               "choices" => [
                 %{
                   "bits_votes" => 0,
                   "channel_points_votes" => 0,
                   "id" => "4c123012-1351-4f33-84b7-43856e7a0f47",
                   "title" => "Heads",
                   "votes" => 4
                 },
                 %{
                   "bits_votes" => 0,
                   "channel_points_votes" => 0,
                   "id" => "279087e3-54a7-467e-bcd0-c1393fcea4f0",
                   "title" => "Tails",
                   "votes" => 3
                 }
               ],
               "duration" => 1800,
               "id" => "ed961efd-8a3f-4cf5-a9d0-e616c590cd2a",
               "started_at" => "2021-03-19T06:08:33.871278372Z",
               "status" => "ACTIVE",
               "title" => "Heads or Tails?"
             }
    end
  end

  describe "end_poll/2" do
    test "can end a poll", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:patch, "/helix/polls"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/polls/end_poll/request.json",
        response: "twitch_api/polls/end_poll/response.json",
        status: 200
      )

      {:ok, poll} = TwitchApi.end_poll(scope, "ed961efd-8a3f-4cf5-a9d0-e616c590cd2a")

      assert poll == %{
               "bits_per_vote" => 0,
               "bits_voting_enabled" => false,
               "broadcaster_id" => "141981764",
               "broadcaster_login" => "twitchdev",
               "broadcaster_name" => "TwitchDev",
               "channel_points_voting_enabled" => false,
               "choices" => [
                 %{
                   "bits_votes" => 0,
                   "channel_points_votes" => 0,
                   "id" => "4c123012-1351-4f33-84b7-43856e7a0f47",
                   "title" => "Heads",
                   "votes" => 0
                 },
                 %{
                   "bits_votes" => 0,
                   "channel_points_votes" => 0,
                   "id" => "279087e3-54a7-467e-bcd0-c1393fcea4f0",
                   "title" => "Tails",
                   "votes" => 0
                 }
               ],
               "duration" => 1800,
               "ended_at" => "2021-03-19T06:11:26.746889614Z",
               "id" => "ed961efd-8a3f-4cf5-a9d0-e616c590cd2a",
               "started_at" => "2021-03-19T06:08:33.871278372Z",
               "status" => "TERMINATED",
               "title" => "Heads or Tails?"
             }
    end
  end

  describe "get_poll/2" do
    test "can read a poll status", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/polls"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        params: "twitch_api/polls/get_polls/params.json",
        response: "twitch_api/polls/get_polls/response.json",
        status: 200
      )

      {:ok, poll} = TwitchApi.get_poll(scope, "ed961efd-8a3f-4cf5-a9d0-e616c590cd2a")

      assert poll == %{
               "bits_per_vote" => 0,
               "bits_voting_enabled" => false,
               "broadcaster_id" => "55696719",
               "broadcaster_login" => "twitchdev",
               "broadcaster_name" => "TwitchDev",
               "channel_points_voting_enabled" => false,
               "choices" => [
                 %{
                   "bits_votes" => 0,
                   "channel_points_votes" => 0,
                   "id" => "4c123012-1351-4f33-84b7-43856e7a0f47",
                   "title" => "Heads",
                   "votes" => 0
                 },
                 %{
                   "bits_votes" => 0,
                   "channel_points_votes" => 0,
                   "id" => "279087e3-54a7-467e-bcd0-c1393fcea4f0",
                   "title" => "Tails",
                   "votes" => 0
                 }
               ],
               "duration" => 1800,
               "id" => "ed961efd-8a3f-4cf5-a9d0-e616c590cd2a",
               "started_at" => "2021-03-19T06:08:33.871278372Z",
               "status" => "ACTIVE",
               "title" => "Heads or Tails?",
               "channel_points_per_vote" => 0
             }
    end
  end
end
