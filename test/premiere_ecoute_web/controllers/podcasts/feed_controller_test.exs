defmodule PremiereEcouteWeb.Podcasts.FeedControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  setup do
    user = user_fixture(%{username: "feedstreamer"})
    show = show_fixture(user, %{title: "Feed Show", published: true})
    %{user: user, show: show}
  end

  describe "GET feed.xml" do
    test "serves an RSS feed for a published show", %{conn: conn, show: show} do
      episode = episode_fixture(show, %{title: "Pilot"})

      conn = get(conn, ~p"/podcasts/feedstreamer/#{show.slug}/feed.xml")

      assert response_content_type(conn, :xml) =~ "application/rss+xml"
      body = response(conn, 200)
      assert body =~ "<rss"
      assert body =~ "<title>Feed Show</title>"
      assert body =~ "<title>Pilot</title>"
      assert body =~ episode.guid
      assert body =~ "episodes/#{episode.guid}/audio"
    end

    test "returns 404 for an unpublished show", %{conn: conn, user: user} do
      draft = show_fixture(user, %{title: "Draft", published: false})

      conn = get(conn, ~p"/podcasts/feedstreamer/#{draft.slug}/feed.xml")

      assert response(conn, 404)
    end

    test "returns 404 for an unknown user", %{conn: conn} do
      conn = get(conn, ~p"/podcasts/nobody/whatever/feed.xml")
      assert response(conn, 404)
    end
  end
end
