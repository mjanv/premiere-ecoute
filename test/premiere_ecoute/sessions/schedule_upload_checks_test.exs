defmodule PremiereEcoute.Sessions.ScheduleUploadChecksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
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
    album_id = attrs[:album_id] || elem(Album.create(album_fixture()), 1).id
    attrs = Map.merge(%{user_id: user.id, album_id: album_id, status: :stopped, ended_at: DateTime.utc_now(:second)}, attrs)
    {:ok, session} = ListeningSession.create(attrs)
    Repo.preload(session, :user)
  end

  defp slot(session, replay), do: ReplayVideo.slot(session.replays, replay.id)

  defp manual(fun), do: Oban.Testing.with_testing_mode(:manual, fun)

  describe "schedule_upload_checks/1" do
    test "schedules one job and one pending state per replay at its due date" do
      user = streamer()
      session = session(user)
      [raw, edited] = user.profile.video_settings.replays

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(session.id)
        updated = Repo.reload(session)

        for {replay, hours} <- [{raw, 24}, {edited, 48}] do
          due_at = DateTime.add(session.ended_at, hours, :hour)

          assert_enqueued(
            worker: CheckUploadWorker,
            queue: :uploads,
            args: %{session_id: session.id, replay_id: replay.id, iteration: ReplayVideo.max_iterations()},
            scheduled_at: {due_at, delta: 5}
          )

          assert %{"status" => "pending", "job_id" => job_id, "label" => _} = entry = slot(updated, replay)

          assert is_integer(job_id)
          assert entry["due_at"] == DateTime.to_iso8601(due_at)
          assert Enum.sort(Map.keys(entry)) == ~w(due_at job_id label last_checked_at replay_id status)
        end

        assert length(updated.replays) == 2
        assert length(all_enqueued(worker: CheckUploadWorker)) == 2
      end)
    end

    test "does nothing for a session that does not exist" do
      assert :ok = Sessions.schedule_upload_checks(0)
    end

    test "keeps the other options of the session" do
      session = session(streamer())

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(session.id)

        assert Repo.reload(session).options["autostart"] == session.options["autostart"]
      end)
    end

    test "does nothing twice" do
      session = session(streamer())

      manual(fn ->
        :ok = Sessions.schedule_upload_checks(session.id)
        once = Repo.reload(session)
        :ok = Sessions.schedule_upload_checks(session.id)

        assert Repo.reload(session).replays == once.replays
        assert length(all_enqueued(worker: CheckUploadWorker)) == 2
      end)
    end

    test "leaves the other entries alone and skips a replay that already has one" do
      user = streamer()
      [raw, edited] = user.profile.video_settings.replays
      free = %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/1"}
      linked = %{"label" => "raw", "url" => "https://youtu.be/dQw4w9WgXcQ", "replay_id" => raw.id, "source" => "manual"}
      {:ok, session} = session(user) |> ListeningSession.changeset(%{replays: [free, linked]}) |> Repo.update()

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(session.id)

        assert [^free, ^linked, %{"replay_id" => replay_id, "status" => "pending"} = pending] = Repo.reload(session).replays
        assert replay_id == edited.id
        refute Map.has_key?(pending, "url")
        assert [%{args: %{"replay_id" => ^replay_id}}] = all_enqueued(worker: CheckUploadWorker)
      end)
    end

    test "does nothing when upload reminders are off" do
      session = session(streamer(false))

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(session.id)
        assert Repo.reload(session).replays == session.replays
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "does nothing without replays" do
      user = user_fixture(%{role: :streamer})
      {:ok, user} = User.edit_user_profile(user, %{video_settings: %{reminders_enabled: true}})
      session = session(user)

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(session.id)
        assert Repo.reload(session).replays == session.replays
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "does nothing for a session that ended before tracking started" do
      session = session(streamer(), %{ended_at: DateTime.add(DateTime.utc_now(:second), -2, :day)})

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(session.id)
        assert Repo.reload(session).replays == session.replays
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "does nothing for a session that has not ended or is not an album" do
      user = streamer()
      running = session(user, %{ended_at: nil})
      clip = session(user, %{source: :clip, album_id: running.album_id})

      manual(fn ->
        assert :ok = Sessions.schedule_upload_checks(running.id)
        assert :ok = Sessions.schedule_upload_checks(clip.id)
        assert Repo.reload(running).replays == running.replays
        assert Repo.reload(clip).replays == clip.replays
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end
  end
end
