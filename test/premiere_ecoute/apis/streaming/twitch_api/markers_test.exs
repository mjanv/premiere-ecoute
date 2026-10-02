defmodule PremiereEcoute.Apis.Streaming.TwitchApi.MarkersTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Twitch.Marker

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

  describe "create_marker/2" do
    test "creates a marker and returns a Marker struct", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/streams/markers"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/markers/create_stream_marker/request.json",
        response: "twitch_api/markers/create_stream_marker/response.json",
        status: 200
      )

      {:ok, marker} = TwitchApi.create_marker(scope, "hello, this is a marker!")

      assert marker == %Marker{
               id: "106b8d6243a4f883d25ad75e6cdffdc4",
               created_at: "2018-08-20T20:10:03Z",
               description: "hello, this is a marker!",
               position_seconds: 244
             }
    end
  end

  describe "get_markers/2" do
    test "returns the markers of the broadcaster's latest video", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/streams/markers"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        params: %{"user_id" => "274637212"},
        response: "twitch_api/markers/get_stream_markers/response.json",
        status: 200
      )

      {:ok, markers} = TwitchApi.get_markers(scope)

      assert markers == [
               %Marker{
                 id: "106b8d6243a4f883d25ad75e6cdffdc4",
                 created_at: "2018-08-20T20:10:03Z",
                 description: "hello, this is a marker!",
                 position_seconds: 244,
                 url: "https://twitch.tv/videos/456?t=0h4m06s",
                 video_id: "456"
               },
               %Marker{
                 id: "a2f3b4c5d6e7f8091a2b3c4d5e6f7a8b",
                 created_at: "2018-08-20T20:12:45Z",
                 description: "second marker",
                 position_seconds: 406,
                 url: "https://twitch.tv/videos/456?t=0h6m46s",
                 video_id: "456"
               }
             ]
    end

    test "returns the markers of a given video", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/streams/markers"},
        params: %{"video_id" => "456"},
        response: "twitch_api/markers/get_stream_markers/response.json",
        status: 200
      )

      {:ok, markers} = TwitchApi.get_markers(scope, video_id: "456")

      assert Enum.map(markers, & &1.video_id) == ["456", "456"]
    end

    test "follows the pagination cursor until the last page", %{scope: scope} do
      page = fn id, cursor ->
        %{
          "data" => [
            %{
              "user_id" => "274637212",
              "videos" => [
                %{
                  "video_id" => "456",
                  "markers" => [%{"id" => id, "created_at" => "2018-08-20T20:10:03Z", "position_seconds" => 1}]
                }
              ]
            }
          ],
          "pagination" => if(cursor, do: %{"cursor" => cursor}, else: %{})
        }
      end

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/streams/markers"},
        params: %{"user_id" => "274637212"},
        response: page.("m1", "cursor-1"),
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/streams/markers"},
        params: %{"user_id" => "274637212", "after" => "cursor-1"},
        response: page.("m2", nil),
        status: 200
      )

      {:ok, markers} = TwitchApi.get_markers(scope)

      assert Enum.map(markers, & &1.id) == ["m1", "m2"]
    end
  end
end
