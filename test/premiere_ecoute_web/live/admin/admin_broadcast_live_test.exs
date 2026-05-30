defmodule PremiereEcouteWeb.Admin.AdminBroadcastLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    streamer =
      user_fixture(%{role: :streamer, twitch: %{user_id: "141981764", username: "streamer1", access_token: "streamer_token"}})

    bot = user_fixture(%{role: :bot, twitch: %{user_id: "467189141", access_token: "bot_token"}})
    admin = user_fixture(%{role: :admin})

    Cache.put(:users, :bot, bot)

    start_supervised(PremiereEcoute.Apis.RateLimit.RateLimiter)
    start_supervised(PremiereEcoute.Apis.Streaming.TwitchQueue)

    {:ok, admin: admin, streamer: streamer}
  end

  test "admin can send a chat message to a specific streamer channel", %{conn: conn, admin: admin, streamer: streamer} do
    ApiMock.expect(
      TwitchApi,
      path: {:post, "/helix/chat/messages"},
      request: %{
        "broadcaster_id" => streamer.twitch.user_id,
        "sender_id" => "467189141",
        "message" => "Hello streamers!"
      },
      response: %{"data" => [%{"message_id" => "abc-123", "is_sent" => true}]},
      status: 200
    )

    conn = log_in_user(conn, admin)
    {:ok, lv, _html} = live(conn, ~p"/admin/broadcast")

    html =
      lv
      |> form("form", %{
        "target" => to_string(streamer.id),
        "type" => "chat",
        "message" => "Hello streamers!"
      })
      |> render_submit()

    # Allow TwitchQueue to flush the async message delivery
    :timer.sleep(100)

    # The results panel renders with the streamer's username on success
    assert html =~ "@streamer1"
    assert html =~ "queued"
  end
end
