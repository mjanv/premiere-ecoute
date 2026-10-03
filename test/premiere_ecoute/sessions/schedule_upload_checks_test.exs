defmodule PremiereEcoute.Sessions.ScheduleUploadChecksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker

  @channel_id "UC" <> String.duplicate("a", 22)

  defp streamer(reminders_enabled \\ true) do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{video_settings: %{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}})

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{
        video_settings: %{
          replays: [
            %{name: "raw", channel_id: channel_id, delay_hours: 24},
            %{name: "edited", channel_id: channel_id, delay_hours: 48}
          ]
        }
      })

    {:ok, user} = User.edit_user_profile(User.get!(user.id), %{video_settings: %{reminders_enabled: reminders_enabled}})
    user
  end

  defp session(user, attrs \\ %{}) do
    {:ok, album} = Album.create(album_fixture())
    attrs = Map.merge(%{user_id: user.id, album_id: album.id, status: :stopped, ended_at: DateTime.utc_now(:second)}, attrs)
    {:ok, session} = ListeningSession.create(attrs)
    Repo.preload(session, :user)
  end

  defp manual(fun), do: Oban.Testing.with_testing_mode(:manual, fun)

  describe "schedule_upload_checks/1" do
    test "schedules one job and one pending state per replay at its due date" do
      user = streamer()
      session = session(user)
      [raw, edited] = user.profile.video_settings.replays

      manual(fn ->
        assert {:ok, updated} = Sessions.schedule_upload_checks(session)

        for {replay, hours} <- [{raw, 24}, {edited, 48}] do
          due_at = DateTime.add(session.ended_at, hours, :hour)

          assert_enqueued(
            worker: CheckUploadWorker,
            queue: :uploads,
            args: %{session_id: session.id, replay_id: replay.id},
            scheduled_at: {due_at, delta: 5}
          )

          assert %{
                   "status" => "pending",
                   "job_id" => job_id,
                   "iterations" => 0,
                   "max_iterations" => 7,
                   "interval_hours" => 24,
                   "last_failure" => nil
                 } = updated.options["uploads"][replay.id]

          assert is_integer(job_id)
          assert updated.options["uploads"][replay.id]["due_at"] == DateTime.to_iso8601(due_at)
          assert updated.options["uploads"][replay.id]["next_check_at"] == DateTime.to_iso8601(due_at)
        end

        assert Repo.reload(session).options["uploads"] |> map_size() == 2
        assert length(all_enqueued(worker: CheckUploadWorker)) == 2
      end)
    end

    test "keeps the other options of the session" do
      session = session(streamer())

      manual(fn ->
        assert {:ok, updated} = Sessions.schedule_upload_checks(session)

        assert updated.options["autostart"] == session.options["autostart"]
      end)
    end

    test "does nothing twice" do
      session = session(streamer())

      manual(fn ->
        {:ok, once} = Sessions.schedule_upload_checks(session)
        {:ok, twice} = Sessions.schedule_upload_checks(%{session | options: once.options})

        assert twice.options["uploads"] == once.options["uploads"]
        assert length(all_enqueued(worker: CheckUploadWorker)) == 2
      end)
    end

    test "does nothing when upload reminders are off" do
      session = session(streamer(false))

      manual(fn ->
        assert {:ok, ^session} = Sessions.schedule_upload_checks(session)
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "does nothing without replays" do
      user = user_fixture(%{role: :streamer})
      {:ok, user} = User.edit_user_profile(user, %{video_settings: %{reminders_enabled: true}})
      session = session(user)

      manual(fn ->
        assert {:ok, ^session} = Sessions.schedule_upload_checks(session)
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "does nothing for a session that ended before tracking started" do
      session = session(streamer(), %{ended_at: DateTime.add(DateTime.utc_now(:second), -2, :day)})

      manual(fn ->
        assert {:ok, ^session} = Sessions.schedule_upload_checks(session)
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "does nothing for a session that has not ended or is not an album" do
      user = streamer()
      running = session(user, %{ended_at: nil})
      clip = %{running | source: :clip, ended_at: DateTime.utc_now(:second)}

      manual(fn ->
        assert {:ok, ^running} = Sessions.schedule_upload_checks(running)
        assert {:ok, ^clip} = Sessions.schedule_upload_checks(clip)
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end
  end
end
