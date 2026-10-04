defmodule PremiereEcoute.Sessions.Workers.CheckUploadNowWorkerTest do
  use PremiereEcoute.DataCase, async: true

  import ExUnit.CaptureLog

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Sessions.Workers.CheckUploadNowWorker
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker
  alias PremiereEcoute.Youtube.Video

  @channel_id "UC" <> String.duplicate("a", 22)

  defp manual(fun), do: Oban.Testing.with_testing_mode(:manual, fun)

  # A session with one pending replay ("raw") and the live job of its scheduled checks.
  defp setup_session(status \\ "pending") do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{video_settings: %{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}})

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{video_settings: %{replays: [%{name: "raw", channel_id: channel_id}]}})

    [replay] = user.profile.video_settings.replays
    {:ok, album} = Album.create(album_fixture())

    {:ok, session} =
      ListeningSession.create(%{
        user_id: user.id,
        album_id: album.id,
        status: :stopped,
        ended_at: DateTime.add(DateTime.utc_now(:second), -2, :hour)
      })

    {:ok, job} =
      CheckUploadWorker.start(%{session_id: session.id, replay_id: replay.id, iteration: 4}, schedule_in: 3600)

    slot = %{
      "replay_id" => replay.id,
      "label" => "raw",
      "status" => status,
      "job_id" => job.id,
      "due_at" => "2026-10-03T10:00:00Z",
      "last_checked_at" => nil
    }

    {:ok, session} = session |> ListeningSession.changeset(%{replays: [slot]}) |> Repo.update()
    PubSub.subscribe("uploads:#{user.id}")

    {session, replay, job}
  end

  defp video do
    %Video{
      id: "abc",
      url: "https://www.youtube.com/watch?v=abc",
      title: "Sample Artist - Sample Album",
      channel_id: @channel_id,
      channel_title: "Lanfeust Plays",
      published_at: "2026-10-04T10:00:00Z",
      privacy: :public,
      thumbnail_url: "https://i.ytimg.com/vi/abc/hq.jpg"
    }
  end

  defp run(session, replay), do: perform_job(CheckUploadNowWorker, %{session_id: session.id, replay_id: replay.id})
  defp slot(session, replay), do: ReplayVideo.slot(ListeningSession.get(session.id).replays, replay.id)
  defp job_state(id), do: Repo.get!(Oban.Job, id, prefix: "oban").state

  test "settles the replay as found, cancels the scheduled job and says so" do
    manual(fn ->
      {session, replay, job} = setup_session()
      expect(YoutubeApi, :get_channel_videos, fn @channel_id, _ -> {:ok, [video()]} end)

      assert :ok = run(session, replay)

      assert %{"status" => "found", "job_id" => nil, "source" => "auto", "url" => _} = slot(session, replay)
      assert job_state(job.id) == "cancelled"
      assert_received {:replay_checked, session_id, replay_id, :found}
      assert {session_id, replay_id} == {session.id, replay.id}
    end)
  end

  test "leaves the schedule alone when the video is not found" do
    manual(fn ->
      {session, replay, job} = setup_session()
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      assert :ok = run(session, replay)

      assert %{"status" => "pending", "job_id" => job_id, "last_checked_at" => checked_at} = slot(session, replay)
      assert job_id == job.id
      assert is_binary(checked_at)
      assert job_state(job.id) == "scheduled"
      assert Repo.get!(Oban.Job, job.id, prefix: "oban").args["iteration"] == 4
      assert all_enqueued(worker: CheckUploadWorker) |> length() == 1
      assert_received {:replay_checked, _, _, :not_found}
    end)
  end

  test "reports a YouTube failure without touching the schedule" do
    manual(fn ->
      {session, replay, job} = setup_session()
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:error, "YouTube API error: 403"} end)

      assert :ok = run(session, replay)

      assert %{"status" => "pending", "job_id" => job_id} = slot(session, replay)
      assert job_id == job.id
      assert_received {:replay_checked, _, _, :error}
    end)
  end

  test "cancels, and tells the page, when the replay is not pending anymore" do
    manual(fn ->
      {session, replay, _job} = setup_session("skipped")

      assert {:cancel, :invalid_transition} = run(session, replay)
      assert_received {:replay_checked, _, _, :settled}
      assert %{"status" => "skipped"} = slot(session, replay)
    end)
  end

  test "cancels when the session is gone" do
    assert {:cancel, :not_found} = perform_job(CheckUploadNowWorker, %{session_id: 0, replay_id: "x"})
  end

  test "logs each outcome" do
    Logger.put_module_level(CheckUploadNowWorker, :info)
    on_exit(fn -> Logger.delete_module_level(CheckUploadNowWorker) end)

    manual(fn ->
      {session, replay, _job} = setup_session()
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)
      log = capture_log([level: :info], fn -> run(session, replay) end)
      assert log =~ "[info] CheckUploadNowWorker: video not found yet for replay raw of session #{session.id}"

      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:error, "YouTube API error: 403"} end)
      log = capture_log([level: :info], fn -> run(session, replay) end)
      assert log =~ "[error] CheckUploadNowWorker: check failed for replay raw of session #{session.id}"
      assert log =~ "YouTube API error: 403"

      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, [video()]} end)
      log = capture_log([level: :info], fn -> run(session, replay) end)
      assert log =~ "[info] CheckUploadNowWorker: found https://www.youtube.com/watch?v=abc for replay raw"
    end)
  end
end
