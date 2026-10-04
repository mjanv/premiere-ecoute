defmodule PremiereEcouteWeb.Accounts.AccountFeaturesLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Accounts.User

  describe "clip overlay URL" do
    test "shows the clip overlay URL when selected", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/account/features")

      html =
        view
        |> element("form[phx-change='change_overlay_score_type']")
        |> render_change(%{"score_type" => "clip"})

      assert html =~ "/sessions/overlay/#{user.username}/clip"
    end
  end

  describe "youtube channels and replays" do
    @channel_id "UC" <> String.duplicate("a", 22)

    test "adds a channel then a replay, and saves them", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/users/account/features")

      html =
        view
        |> form("#youtube-settings-form", profile: %{video_settings: %{channels_sort: ["new"]}})
        |> render_change()

      assert html =~ "Label"

      view
      |> form("#youtube-settings-form",
        profile: %{video_settings: %{channels: %{"0" => %{label: "Main", youtube_channel_id: @channel_id}}}}
      )
      |> render_submit()

      [channel] = User.get!(user.id).profile.video_settings.channels
      assert channel.label == "Main"

      view
      |> form("#youtube-settings-form", profile: %{video_settings: %{replays_sort: ["new"]}})
      |> render_change()

      view
      |> form("#youtube-settings-form",
        profile: %{
          video_settings: %{
            reminders_enabled: "true",
            replays: %{"0" => %{name: "raw", channel_id: channel.id, delay_hours: 12}}
          }
        }
      )
      |> render_submit()

      settings = User.get!(user.id).profile.video_settings
      assert [%{name: "raw", delay_hours: 12, channel_id: channel_id}] = settings.replays
      assert channel_id == channel.id
      assert settings.reminders_enabled
      assert settings.tracking_since == Date.utc_today()
    end

    test "shows validation errors for an invalid channel id", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/users/account/features")

      view
      |> form("#youtube-settings-form", profile: %{video_settings: %{channels_sort: ["new"]}})
      |> render_change()

      html =
        view
        |> form("#youtube-settings-form",
          profile: %{video_settings: %{channels: %{"0" => %{label: "Main", youtube_channel_id: "nope"}}}}
        )
        |> render_change()

      assert html =~ "must be a YouTube channel id"
    end

    test "dims channels and replays while reminders are disabled", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/users/account/features")

      assert html =~ ~r/id="youtube-channels"[^>]*opacity-40/s

      html =
        view
        |> form("#youtube-settings-form", profile: %{video_settings: %{reminders_enabled: "true"}})
        |> render_change()

      refute html =~ ~r/id="youtube-channels"[^>]*opacity-40/s
    end
  end
end
