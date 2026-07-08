defmodule PremiereEcouteWeb.Chat.HashtagBannerLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Sessions.Chat.HashtagMessage
  alias PremiereEcouteCore.Cache

  setup do
    Cache.clear(:hashtags)
    on_exit(fn -> Cache.clear(:hashtags) end)

    user = user_fixture(%{twitch: %{user_id: "1234"}})

    {:ok, user: user}
  end

  describe "mount/3" do
    test "redirects to home for an unknown username", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/chat/overlay/unknown-user")
    end

    test "renders with no messages when the cache is empty", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/chat/overlay/#{user.username}")

      refute html =~ "hashtag-ticker"
    end

    test "renders cached hashtag messages seeded at mount", %{conn: conn, user: user} do
      HashtagMessage.put("1234", "#hype", "#hype this album is fire")

      {:ok, _view, html} = live(conn, ~p"/chat/overlay/#{user.username}")

      assert html =~ "#hype"
      assert html =~ "this album is fire"
    end

    test "renders without messages when the streamer has no linked twitch account", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} = live(conn, ~p"/chat/overlay/#{user.username}")

      refute html =~ "hashtag-ticker"
    end
  end

  describe "handle_info/2 - PubSub events" do
    test "appends a new hashtag message pushed live", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/chat/overlay/#{user.username}")

      HashtagMessage.put("1234", "#newalbum", "#newalbum just dropped")

      html = render(view)

      assert html =~ "#newalbum"
      assert html =~ "just dropped"
    end
  end

  describe "handle_info/2 - :prune_expired" do
    test "removes messages older than the cache TTL from the live banner", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/chat/overlay/#{user.username}")

      HashtagMessage.put("1234", "#newalbum", "#newalbum just dropped")
      html = render(view)
      assert html =~ "just dropped"

      stale_at = DateTime.add(DateTime.utc_now(), -HashtagMessage.ttl() - 1_000, :millisecond)

      :sys.replace_state(view.pid, fn state ->
        put_in(state.socket.assigns.messages, [
          %{broadcaster_id: "1234", hashtag: "#newalbum", message: "#newalbum just dropped", inserted_at: stale_at}
        ])
      end)

      send(view.pid, :prune_expired)
      html = render(view)

      refute html =~ "just dropped"
    end
  end
end
