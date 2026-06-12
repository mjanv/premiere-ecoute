defmodule PremiereEcouteWeb.Admin.PodcastsLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Podcasts

  setup %{conn: conn} do
    admin = user_fixture(%{role: :admin})
    %{conn: log_in_user(conn, admin)}
  end

  test "lists shows from all streamers", %{conn: conn} do
    show_fixture(user_fixture(%{username: "owner_a"}), %{title: "Show A"})
    show_fixture(user_fixture(%{username: "owner_b"}), %{title: "Show B"})

    {:ok, _lv, html} = live(conn, ~p"/admin/podcasts")

    assert html =~ "Show A"
    assert html =~ "Show B"
    assert html =~ "owner_a"
  end

  test "admin can unpublish a show", %{conn: conn} do
    show = show_fixture(user_fixture(), %{title: "Taken Down", published: true})

    {:ok, lv, _html} = live(conn, ~p"/admin/podcasts")
    lv |> element("button[phx-click='unpublish'][phx-value-id='#{show.id}']") |> render_click()

    refute Podcasts.get_show(show.id).published
  end

  test "admin can delete a show", %{conn: conn} do
    show = show_fixture(user_fixture(), %{title: "Gone"})

    {:ok, lv, _html} = live(conn, ~p"/admin/podcasts")
    lv |> element("button[phx-click='delete'][phx-value-id='#{show.id}']") |> render_click()

    assert is_nil(Podcasts.get_show(show.id))
  end

  test "non-admin is redirected", %{conn: _conn} do
    viewer_conn = log_in_user(Phoenix.ConnTest.build_conn(), user_fixture(%{role: :viewer}))

    assert {:error, {:redirect, %{to: "/"}}} = live(viewer_conn, ~p"/admin/podcasts")
  end
end
