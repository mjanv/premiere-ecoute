defmodule PremiereEcouteWeb.Podcasts.ShowLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    user = user_fixture(%{username: "weblistener"})
    %{user: user}
  end

  describe "show page" do
    test "renders a published show with its episodes", %{conn: conn, user: user} do
      show = show_fixture(user, %{title: "Web Show", published: true})
      episode = episode_fixture(show, %{title: "Web Episode"})

      {:ok, _view, html} = live(conn, ~p"/podcasts/weblistener/#{show.slug}")

      assert html =~ "Web Show"
      assert html =~ "Web Episode"
      assert html =~ "episodes/#{episode.guid}/audio"
    end

    test "renders a not-found message for an unpublished show", %{conn: conn, user: user} do
      show = show_fixture(user, %{title: "Hidden", published: false})

      {:ok, _view, html} = live(conn, ~p"/podcasts/weblistener/#{show.slug}")

      assert html =~ "not found"
    end
  end

  describe "shows index" do
    test "lists a streamer's published shows", %{conn: conn, user: user} do
      show_fixture(user, %{title: "Published One", published: true})
      show_fixture(user, %{title: "Unpublished Two", published: false})

      {:ok, _view, html} = live(conn, ~p"/podcasts/weblistener")

      assert html =~ "Published One"
      refute html =~ "Unpublished Two"
    end
  end
end
