defmodule PremiereEcoute.Sessions.ListeningSession.EventHandlerUploadChecksTest do
  # Not async: the test removes an application setting that the other tests read.
  use PremiereEcoute.DataCase, async: false

  import ExUnit.CaptureLog

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Sessions.ListeningSession.EventHandler
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Services.ReplayVideo

  test "stopping a session still works when the upload checks cannot be scheduled" do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{
        video_settings: %{channels: [%{label: "Main", youtube_channel_id: "UC" <> String.duplicate("a", 22)}]}
      })

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{
        video_settings: %{replays: [%{name: "raw", channel_id: channel_id}], reminders_enabled: true}
      })

    session = session_fixture(%{user_id: user.id, status: :stopped, ended_at: DateTime.utc_now(:second)})

    config = Application.fetch_env!(:premiere_ecoute, ReplayVideo)
    Application.delete_env(:premiere_ecoute, ReplayVideo)
    on_exit(fn -> Application.put_env(:premiere_ecoute, ReplayVideo, config) end)

    log =
      capture_log(fn ->
        Oban.Testing.with_testing_mode(:manual, fn ->
          assert :ok = EventHandler.dispatch(%SessionStopped{session_id: session.id, user_id: user.id})
        end)
      end)

    assert log =~ "Upload checks of session #{session.id} were not scheduled"
  end
end
