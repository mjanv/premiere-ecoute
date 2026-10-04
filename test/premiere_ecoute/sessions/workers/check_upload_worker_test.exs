defmodule PremiereEcoute.Sessions.Workers.CheckUploadWorkerTest do
  use PremiereEcoute.DataCase, async: true

  import ExUnit.CaptureLog

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker
  alias PremiereEcoute.Youtube.Video

  @channel_id "UC" <> String.duplicate("a", 22)

  defp state(attrs \\ %{}) do
    due_at = DateTime.to_iso8601(DateTime.add(DateTime.utc_now(:second), -1, :hour))

    Map.merge(
      %{
        "status" => "pending",
        "job_id" => nil,
        "due_at" => due_at,
        "last_checked_at" => nil
      },
      attrs
    )
  end

  defp setup_session(states) do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{video_settings: %{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}})

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{
        video_settings: %{replays: [%{name: "raw", channel_id: channel_id}, %{name: "edited", channel_id: channel_id}]}
      })

    [raw, edited] = user.profile.video_settings.replays
    {:ok, album} = Album.create(album_fixture())

    slots =
      for {replay, state} <- Enum.zip([raw, edited], states), state != nil do
        Map.merge(%{"replay_id" => replay.id, "label" => replay.name}, state)
      end

    {:ok, session} =
      ListeningSession.create(%{
        user_id: user.id,
        album_id: album.id,
        status: :stopped,
        ended_at: DateTime.add(DateTime.utc_now(:second), -2, :hour),
        replays: slots
      })

    {session, raw, edited}
  end

  defp video do
    %Video{
      id: "vid#{System.unique_integer([:positive])}",
      url: "https://www.youtube.com/watch?v=abc",
      title: "Sample Artist - Sample Album",
      channel_id: @channel_id,
      published_at: "2026-10-04T10:00:00Z",
      privacy: :public,
      thumbnail_url: "https://i.ytimg.com/vi/abc/hq.jpg"
    }
  end

  defp run(session, replay, iteration \\ 3) do
    Oban.Testing.with_testing_mode(:manual, fn ->
      result = perform_job(CheckUploadWorker, %{session_id: session.id, replay_id: replay.id, iteration: iteration})
      {result, all_enqueued(worker: CheckUploadWorker)}
    end)
  end

  # The tracking state of each replay, as the slots of the session hold it.
  defp uploads(session) do
    for %{"replay_id" => replay_id} = entry <- ListeningSession.get(session.id).replays, into: %{} do
      {replay_id, Map.drop(entry, ["replay_id", "label"])}
    end
  end

  describe "perform/1" do
    test "stores the found video and finishes" do
      {session, raw, _edited} = setup_session([state(), state()])
      expect(YoutubeApi, :get_channel_videos, fn @channel_id, _ -> {:ok, [video()]} end)

      assert {:ok, []} = run(session, raw)

      assert %{"status" => "found", "job_id" => nil} = uploads(session)[raw.id]

      assert %{"thumbnail_url" => "https://i.ytimg.com/vi/abc/hq.jpg", "source" => "auto", "url" => _} = uploads(session)[raw.id]
    end

    test "inserts the next check with one iteration less" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      assert {:ok, [job]} = run(session, raw, 3)
      assert_in_delta DateTime.diff(job.scheduled_at, DateTime.utc_now()), 24 * 3600, 5
      assert job.args == %{"session_id" => session.id, "replay_id" => raw.id, "iteration" => 2}

      assert %{"status" => "pending", "job_id" => job_id} = uploads(session)[raw.id]
      assert job_id == job.id
    end

    test "keeps looking after an API error" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:error, "YouTube API error: 403"} end)

      assert {:ok, [%{args: %{"iteration" => 2}}]} = run(session, raw, 3)

      assert %{"status" => "pending"} = uploads(session)[raw.id]
    end

    test "starts from the max iteration when its args carry none" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        perform_job(CheckUploadWorker, %{session_id: session.id, replay_id: raw.id})

        assert [%{args: %{"iteration" => iteration}}] = all_enqueued(worker: CheckUploadWorker)
        assert iteration == ReplayVideo.max_iterations() - 1
      end)
    end

    test "exhausts the replay when the last iteration fails" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      assert {:ok, []} = run(session, raw, 1)

      assert %{"status" => "exhausted", "job_id" => nil} = uploads(session)[raw.id]
    end

    test "logs a success at info level" do
      Logger.put_module_level(CheckUploadWorker, :info)
      on_exit(fn -> Logger.delete_module_level(CheckUploadWorker) end)
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, [video()]} end)

      log = capture_log([level: :info], fn -> run(session, raw) end)

      assert log =~ "[info] CheckUploadWorker: found https://www.youtube.com/watch?v=abc for replay raw of session #{session.id}"
      refute log =~ "[error]"
    end

    test "logs the reason of a failure at error level" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:error, "YouTube API error: 403"} end)

      log = capture_log(fn -> run(session, raw, 3) end)

      assert log =~ "[error] CheckUploadWorker: check failed for replay raw of session #{session.id}, 2 checks left"
      assert log =~ "YouTube API error: 403"
      refute log =~ "[warning]"
    end

    test "logs a video not found yet at info level" do
      Logger.put_module_level(CheckUploadWorker, :info)
      on_exit(fn -> Logger.delete_module_level(CheckUploadWorker) end)
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      log = capture_log([level: :info], fn -> run(session, raw, 3) end)

      assert log =~
               "[info] CheckUploadWorker: video not found yet for replay raw of session #{session.id}, 2 checks left: :not_found"

      refute log =~ "[error]"
      refute log =~ "[warning]"
    end

    test "logs the exhaustion at warning level, after the last failed check" do
      Logger.put_module_level(CheckUploadWorker, :info)
      on_exit(fn -> Logger.delete_module_level(CheckUploadWorker) end)
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      log = capture_log([level: :info], fn -> run(session, raw, 1) end)

      assert log =~ "[info] CheckUploadWorker: video not found yet for replay raw of session #{session.id}, 0 checks left"
      assert log =~ "[warning] CheckUploadWorker: gave up on replay raw of session #{session.id}"
      refute log =~ "[error]"
    end

    test "leaves the other replays untouched" do
      other = state(%{"last_checked_at" => "2026-10-03T10:00:00Z"})
      {session, raw, edited} = setup_session([state(), other])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, [video()]} end)

      assert {:ok, []} = run(session, raw)

      assert uploads(session)[edited.id] == other
    end

    test "cancels when the replay is not pending anymore" do
      skipped = state(%{"status" => "skipped"})
      {session, raw, _edited} = setup_session([skipped, nil])

      assert {{:cancel, :not_pending}, []} = run(session, raw)
      assert uploads(session)[raw.id] == skipped
    end

    test "cancels when the replay has no state" do
      {session, _raw, edited} = setup_session([state(), nil])

      assert {{:cancel, :gone}, []} = run(session, edited)
    end

    test "cancels when the session is gone" do
      {_session, raw, _edited} = setup_session([state(), nil])

      assert {:cancel, :gone} = perform_job(CheckUploadWorker, %{session_id: 0, replay_id: raw.id})
    end
  end

  # The sandbox shares one connection, so two workers cannot truly run in parallel here. Instead, the second
  # worker runs to completion inside the first one's YouTube call, which is exactly the window between its
  # unlocked read and its locked write.
  describe "perform/1 telling the page" do
    defp subscribe(session), do: PubSub.subscribe("uploads:#{session.user_id}")

    test "broadcasts when the video is found" do
      {session, raw, _edited} = setup_session([state(), nil])
      subscribe(session)
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, [video()]} end)

      run(session, raw)

      assert_received {:replay_updated, session_id, replay_id}
      assert {session_id, replay_id} == {session.id, raw.id}
    end

    test "broadcasts when a check fails and the next one is scheduled, and when the replay is exhausted" do
      {session, raw, _edited} = setup_session([state(), nil])
      subscribe(session)
      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ -> {:ok, []} end)

      run(session, raw, 3)
      assert_received {:replay_updated, _, _}

      run(session, raw, 1)
      assert_received {:replay_updated, _, _}
    end

    test "says nothing when the slot is not pending anymore" do
      {session, raw, _edited} = setup_session([state(%{"status" => "skipped"}), nil])
      subscribe(session)

      run(session, raw)

      refute_received {:replay_updated, _, _}
    end
  end

  describe "perform/1 with another replay of the session finishing meanwhile" do
    test "keeps what the other worker stored when this one finds its video too" do
      {session, raw, edited} = setup_session([state(), state()])

      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ ->
        unless Process.get(:nested) do
          Process.put(:nested, true)
          assert :ok = perform_job(CheckUploadWorker, %{session_id: session.id, replay_id: edited.id})
        end

        {:ok, [video()]}
      end)

      assert {:ok, []} = run(session, raw)

      assert %{"status" => "found"} = uploads(session)[raw.id]
      assert %{"status" => "found"} = uploads(session)[edited.id]

      assert %{"url" => _, "source" => "auto"} = uploads(session)[raw.id]
      assert %{"url" => _, "source" => "auto"} = uploads(session)[edited.id]
    end

    test "keeps what the other worker stored when this one does not find its video" do
      {session, raw, edited} = setup_session([state(), state()])

      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ ->
        if Process.get(:nested) do
          {:ok, [video()]}
        else
          Process.put(:nested, true)
          assert :ok = perform_job(CheckUploadWorker, %{session_id: session.id, replay_id: edited.id})
          {:ok, []}
        end
      end)

      assert {:ok, [job]} = run(session, raw)

      assert %{"status" => "found"} = uploads(session)[edited.id]
      assert %{"status" => "pending", "job_id" => job_id} = uploads(session)[raw.id]
      assert job_id == job.id
      assert %{"url" => _} = uploads(session)[edited.id]
      refute Map.has_key?(uploads(session)[raw.id], "url")
    end
  end
end
