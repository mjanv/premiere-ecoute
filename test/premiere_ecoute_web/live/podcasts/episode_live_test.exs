defmodule PremiereEcouteWeb.Podcasts.EpisodeLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    user = user_fixture(%{username: "epstreamer"})
    %{show: show_fixture(user, %{title: "Ep Show", published: true})}
  end

  test "renders a published episode with a player and back link", %{conn: conn, show: show} do
    episode = episode_fixture(show, %{title: "Deep Link Ep"})

    {:ok, _lv, html} = live(conn, ~p"/podcasts/epstreamer/#{show.slug}/episodes/#{episode.guid}")

    assert html =~ "Deep Link Ep"
    assert html =~ "Ep Show"
    assert html =~ "episodes/#{episode.guid}/audio"
  end

  test "shows not found for an unknown episode", %{conn: conn, show: show} do
    {:ok, _lv, html} = live(conn, ~p"/podcasts/epstreamer/#{show.slug}/episodes/does-not-exist")
    assert html =~ "not found"
  end
end
