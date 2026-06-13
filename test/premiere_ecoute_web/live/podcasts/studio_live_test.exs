defmodule PremiereEcouteWeb.Podcasts.StudioLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Podcasts

  setup %{conn: conn} do
    streamer = user_fixture(%{role: :streamer, username: "studiostreamer"})
    %{conn: log_in_user(conn, streamer), streamer: streamer}
  end

  describe "shows index" do
    test "lists the streamer's own shows", %{conn: conn, streamer: streamer} do
      show_fixture(streamer, %{title: "My First Pod"})

      {:ok, _lv, html} = live(conn, ~p"/studio/podcasts")

      assert html =~ "My First Pod"
    end
  end

  describe "create show" do
    test "creates a show and redirects to its dashboard", %{conn: conn, streamer: streamer} do
      {:ok, lv, _html} = live(conn, ~p"/studio/podcasts/new")

      lv
      |> form("#show-form", show: %{title: "Brand New Show", language: "en", category: "Music"})
      |> render_submit()

      {path, _flash} = assert_redirect(lv)
      assert path =~ ~r"^/studio/podcasts/\d+$"

      assert [%{title: "Brand New Show"}] = Podcasts.shows_for_user(streamer)
    end
  end

  describe "dashboard" do
    test "publishes a show", %{conn: conn, streamer: streamer} do
      show = show_fixture(streamer, %{published: false})

      {:ok, lv, _html} = live(conn, ~p"/studio/podcasts/#{show.id}")
      lv |> element("button[phx-click='publish_show']") |> render_click()

      assert Podcasts.get_show(show.id).published
    end

    test "publishes a ready episode now (empty schedule)", %{conn: conn, streamer: streamer} do
      show = show_fixture(streamer, %{published: true})
      episode = episode_fixture(show, %{status: :ready, published_at: nil})

      {:ok, lv, _html} = live(conn, ~p"/studio/podcasts/#{show.id}")
      lv |> form("form[phx-submit='publish_episode']") |> render_submit()

      assert Podcasts.get_episode(episode.id).published_at
    end

    test "schedules a ready episode for a future date", %{conn: conn, streamer: streamer} do
      show = show_fixture(streamer, %{published: true})
      episode = episode_fixture(show, %{status: :ready, published_at: nil})

      {:ok, lv, _html} = live(conn, ~p"/studio/podcasts/#{show.id}")
      lv |> form("form[phx-submit='publish_episode']", %{"at" => "2099-01-01T10:00"}) |> render_submit()

      published_at = Podcasts.get_episode(episode.id).published_at
      assert published_at
      assert DateTime.compare(published_at, DateTime.utc_now()) == :gt
    end

    test "blocks access to another streamer's show", %{conn: conn} do
      other = show_fixture(user_fixture(%{role: :streamer}))

      assert {:error, {:redirect, %{to: "/studio/podcasts"}}} = live(conn, ~p"/studio/podcasts/#{other.id}")
    end
  end
end
