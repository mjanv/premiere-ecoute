defmodule PremiereEcouteWeb.Radio.ViewerLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Radio.RadioTrack

  describe "add_track_to_wantlist" do
    setup do
      streamer = user_fixture(%{role: :streamer})

      {:ok, _} =
        PremiereEcoute.Accounts.User.edit_user_profile(streamer, %{
          "radio_settings" => %{"visibility" => "public", "enabled" => true, "retention_days" => 7}
        })

      streamer = PremiereEcoute.Accounts.get_user_by_username(streamer.username)

      viewer = user_fixture(%{role: :viewer})

      {:ok, single} =
        single_fixture(%{provider_ids: %{spotify: "sp_radio_track_1"}, name: "Around the World"})
        |> Single.create_if_not_exists()

      {:ok, _track} =
        RadioTrack.insert(streamer.id, %{
          provider_ids: %{spotify: "sp_radio_track_1"},
          name: "Around the World",
          artist: "Daft Punk",
          started_at: DateTime.utc_now()
        })

      {:ok, streamer: streamer, viewer: viewer, single: single}
    end

    test "dispatches a WantlistSave notification via PubSub after saving", %{conn: conn, streamer: streamer, viewer: viewer} do
      conn = log_in_user(conn, viewer)

      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "user:#{viewer.id}")

      {:ok, lv, _html} = live(conn, ~p"/radio/#{streamer.username}")

      lv |> element("[phx-click='add_track_to_wantlist'][phx-value-spotify-id='sp_radio_track_1']") |> render_click()

      assert_receive {:user_notification, notification, rendered}
      assert notification.type == "wantlist_save"
      assert rendered.title == "Around the World"
      assert rendered.body == "Daft Punk"
      assert rendered.path == "/wantlist"
    end

    test "does not dispatch notification when user is not logged in", %{conn: conn, streamer: streamer} do
      {:ok, _lv, _html} = live(conn, ~p"/radio/#{streamer.username}")

      # No PubSub message should arrive since the event is a no-op for unauthenticated users
      refute_receive {:user_notification, _notification, _rendered}, 200
    end
  end
end
