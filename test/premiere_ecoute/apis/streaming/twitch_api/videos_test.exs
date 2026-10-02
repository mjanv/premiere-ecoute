defmodule PremiereEcoute.Apis.Streaming.TwitchApi.VideosTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Twitch.Video

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

  @video %Video{
    id: "335921245",
    stream_id: "40250115755",
    user_id: "274637212",
    user_login: "torpedo09",
    user_name: "Torpedo09",
    title: "Listening session",
    description: "Weekly album premiere",
    created_at: "2018-11-14T21:30:18Z",
    published_at: "2018-11-14T22:04:30Z",
    url: "https://www.twitch.tv/videos/335921245",
    thumbnail_url:
      "https://static-cdn.jtvnw.net/cf_vods/d2nvs31859zcd8/twitchdev/335921245/ce0f3a7f-57a3-4152-bc06-0c6610189fb3/thumb/index-0000000000-%{width}x%{height}.jpg",
    viewable: "public",
    view_count: 1_863_062,
    language: "en",
    type: :archive,
    duration: "1h2m3s",
    muted_segments: [%{duration: 30, offset: 120}]
  }

  describe "get_video/2" do
    test "returns a Video struct", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        headers: [
          {"authorization", "Bearer 2gbdx6oar67tqtcmt49t3wpcgycthx"},
          {"content-type", "application/json"}
        ],
        params: %{"id" => "335921245"},
        response: "twitch_api/videos/get_videos/response.json",
        status: 200
      )

      assert {:ok, @video} = TwitchApi.get_video(scope, "335921245")
    end
  end

  describe "get_videos/2" do
    test "returns the broadcaster's videos", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{"user_id" => "274637212", "first" => "100"},
        response: "twitch_api/videos/get_videos/response.json",
        status: 200
      )

      assert {:ok, [@video]} = TwitchApi.get_videos(scope)
    end

    test "filters by type, period and sort", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{
          "user_id" => "274637212",
          "first" => "100",
          "type" => "archive",
          "period" => "week",
          "sort" => "views"
        },
        response: "twitch_api/videos/get_videos/response.json",
        status: 200
      )

      assert {:ok, [@video]} = TwitchApi.get_videos(scope, type: :archive, period: :week, sort: :views)
    end

    test "follows the pagination cursor until the last page", %{scope: scope} do
      page = fn id, cursor ->
        %{
          "data" => [%{"id" => id, "type" => "archive"}],
          "pagination" => if(cursor, do: %{"cursor" => cursor}, else: %{})
        }
      end

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{"user_id" => "274637212", "first" => "100"},
        response: page.("v1", "cursor-1"),
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{"user_id" => "274637212", "first" => "100", "after" => "cursor-1"},
        response: page.("v2", nil),
        status: 200
      )

      {:ok, videos} = TwitchApi.get_videos(scope)

      assert Enum.map(videos, & &1.id) == ["v1", "v2"]
    end

    test "stops fetching once the limit is reached", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{"user_id" => "274637212", "first" => "2"},
        body: %{
          "data" => [%{"id" => "v1"}, %{"id" => "v2"}],
          "pagination" => %{"cursor" => "cursor-1"}
        },
        status: 200
      )

      {:ok, videos} = TwitchApi.get_videos(scope, limit: 2)

      assert Enum.map(videos, & &1.id) == ["v1", "v2"]
    end

    test "requests only the remaining videos on the last page", %{scope: scope} do
      videos = fn range -> Enum.map(range, &%{"id" => "v#{&1}"}) end

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{"user_id" => "274637212", "first" => "100"},
        body: %{"data" => videos.(1..100), "pagination" => %{"cursor" => "cursor-1"}},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/videos"},
        params: %{"user_id" => "274637212", "first" => "50", "after" => "cursor-1"},
        body: %{"data" => videos.(101..150), "pagination" => %{"cursor" => "cursor-2"}},
        status: 200
      )

      {:ok, result} = TwitchApi.get_videos(scope, limit: 150)

      assert length(result) == 150
    end
  end
end
