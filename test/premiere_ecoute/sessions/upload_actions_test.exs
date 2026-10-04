defmodule PremiereEcoute.Sessions.UploadActionsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Sessions.Workers.CheckUploadNowWorker
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker
  alias PremiereEcoute.Youtube.Video

  @channel_id "UC" <> String.duplicate("a", 22)
  @url "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

  defp manual(fun), do: Oban.Testing.with_testing_mode(:manual, fun)

  defp state(attrs) do
    now = DateTime.to_iso8601(DateTime.utc_now(:second))

    Map.merge(
      %{
        "status" => "pending",
        "job_id" => nil,
        "due_at" => now,
        "last_checked_at" => now
      },
      attrs
    )
  end

  # A session with one replay ("raw") whose state is built by `state_fun.(session_id, replay_id)`.
  defp setup_session(state_fun, replays \\ [], album_id \\ nil) do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{video_settings: %{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}})

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{video_settings: %{replays: [%{name: "raw", channel_id: channel_id}]}})

    [replay] = user.profile.video_settings.replays
    album_id = album_id || elem(Album.create(album_fixture()), 1).id

    {:ok, session} =
      ListeningSession.create(%{
        user_id: user.id,
        album_id: album_id,
        status: :stopped,
        ended_at: DateTime.add(DateTime.utc_now(:second), -2, :hour),
        replays: replays
      })

    slot = Map.merge(%{"replay_id" => replay.id, "label" => "raw"}, state_fun.(session.id, replay.id))
    {:ok, session} = session |> ListeningSession.changeset(%{replays: replays ++ [slot]}) |> Repo.update()

    {session, replay}
  end

  defp insert_job(session_id, replay_id) do
    {:ok, job} =
      CheckUploadWorker.start(%{session_id: session_id, replay_id: replay_id, iteration: 3}, schedule_in: 3600)

    job
  end

  defp upload(session, replay), do: ReplayVideo.slot(ListeningSession.get(session.id).replays, replay.id)

  defp refute_found(session, replay) do
    entry = upload(session, replay)
    refute Map.has_key?(entry, "url")
    entry
  end

  defp job_state(id), do: Repo.get!(Oban.Job, id, prefix: "oban").state

  defp video(attrs \\ %{}) do
    struct(
      %Video{
        id: "dQw4w9WgXcQ",
        url: @url,
        title: "Whatever",
        channel_id: @channel_id,
        channel_title: "Lanfeust Plays",
        privacy: :public,
        thumbnail_url: "https://i.ytimg.com/vi/x/hq.jpg"
      },
      attrs
    )
  end

  describe "skip_upload/2" do
    test "skips a pending replay and cancels its job" do
      manual(fn ->
        {session, replay} = setup_session(fn sid, rid -> state(%{"job_id" => insert_job(sid, rid).id}) end)
        job_id = upload(session, replay)["job_id"]

        assert {:ok, _} = Sessions.skip_upload(session.id, replay.id)

        assert %{"status" => "skipped", "job_id" => nil} = upload(session, replay)
        assert job_state(job_id) == "cancelled"
      end)
    end

    test "skips an exhausted or rejected replay, but not a found or skipped one" do
      {%{album_id: album_id}, _} = setup_session(fn _, _ -> state(%{}) end)

      for {status, ok?} <- [{"exhausted", true}, {"rejected", true}, {"found", false}, {"skipped", false}] do
        {session, replay} = setup_session(fn _, _ -> state(%{"status" => status}) end, [], album_id)

        assert match?({:ok, _}, Sessions.skip_upload(session.id, replay.id)) == ok?, status
      end
    end

    test "fails for an unknown session or replay" do
      {session, _replay} = setup_session(fn _, _ -> state(%{}) end)

      assert {:error, :not_found} = Sessions.skip_upload(0, "x")
      assert {:error, :not_found} = Sessions.skip_upload(session.id, "unknown")
    end
  end

  describe "unskip_upload/2 and retry_upload/2" do
    test "unskip revives a skipped replay with a fresh job starting from the max iteration" do
      manual(fn ->
        {session, replay} = setup_session(fn _, _ -> state(%{"status" => "skipped"}) end)

        assert {:ok, _} = Sessions.unskip_upload(session.id, replay.id)

        assert %{"status" => "pending", "job_id" => job_id} = upload(session, replay)
        assert job_state(job_id) == "available"

        assert_enqueued worker: CheckUploadWorker,
                        args: %{session_id: session.id, replay_id: replay.id, iteration: ReplayVideo.max_iterations()}
      end)
    end

    test "retry revives an exhausted replay, and refuses a rejected one" do
      manual(fn ->
        {session, replay} = setup_session(fn _, _ -> state(%{"status" => "exhausted"}) end)
        assert {:ok, _} = Sessions.retry_upload(session.id, replay.id)
        assert %{"status" => "pending", "job_id" => job_id} = upload(session, replay)
        assert is_integer(job_id)

        {session, replay} =
          setup_session(fn _, _ -> state(%{"status" => "rejected"}) end, [], session.album_id)

        assert {:error, :invalid_transition} = Sessions.retry_upload(session.id, replay.id)
      end)
    end

    test "unskip refuses a replay that is not skipped" do
      {session, replay} = setup_session(fn _, _ -> state(%{}) end)

      assert {:error, :invalid_transition} = Sessions.unskip_upload(session.id, replay.id)
    end
  end

  describe "check_upload_now/2" do
    test "enqueues a one-shot check and leaves the schedule alone" do
      manual(fn ->
        {session, replay} = setup_session(fn sid, rid -> state(%{"job_id" => insert_job(sid, rid).id}) end)
        before = upload(session, replay)
        job_id = before["job_id"]

        assert {:ok, %Oban.Job{} = job} = Sessions.check_upload_now(session.id, replay.id)

        assert job.worker == "PremiereEcoute.Sessions.Workers.CheckUploadNowWorker"
        assert_enqueued worker: CheckUploadNowWorker, args: %{session_id: session.id, replay_id: replay.id}

        assert job_state(job_id) == "scheduled"
        assert Repo.get!(Oban.Job, job_id, prefix: "oban").args["iteration"] == 3
        assert upload(session, replay) == before
      end)
    end

    test "does not enqueue a second check while one is waiting" do
      manual(fn ->
        {session, replay} = setup_session(fn _, _ -> state(%{}) end)

        assert {:ok, %Oban.Job{conflict?: false}} = Sessions.check_upload_now(session.id, replay.id)
        assert {:ok, %Oban.Job{conflict?: true}} = Sessions.check_upload_now(session.id, replay.id)
        assert length(all_enqueued(worker: CheckUploadNowWorker)) == 1
      end)
    end

    test "refuses a replay that is not pending" do
      {session, replay} = setup_session(fn _, _ -> state(%{"status" => "exhausted"}) end)

      assert {:error, :invalid_transition} = Sessions.check_upload_now(session.id, replay.id)
    end

    test "fails for an unknown session or replay" do
      {session, _replay} = setup_session(fn _, _ -> state(%{}) end)

      assert {:error, :not_found} = Sessions.check_upload_now(0, "x")
      assert {:error, :invalid_transition} = Sessions.check_upload_now(session.id, "unknown")
    end
  end

  describe "attach_upload/3" do
    test "stores a manual entry, marks the replay found and cancels its job" do
      manual(fn ->
        {session, replay} = setup_session(fn sid, rid -> state(%{"job_id" => insert_job(sid, rid).id}) end)
        job_id = upload(session, replay)["job_id"]
        expect(YoutubeApi, :get_video, fn "dQw4w9WgXcQ" -> {:ok, video()} end)

        assert {:ok, _} = Sessions.attach_upload(session.id, replay.id, @url)

        assert %{"status" => "found", "job_id" => nil} = upload(session, replay)
        assert job_state(job_id) == "cancelled"

        assert [
                 %{
                   "source" => "manual",
                   "label" => "raw",
                   "title" => "Whatever",
                   "channel_title" => "Lanfeust Plays",
                   "video_id" => "dQw4w9WgXcQ"
                 } =
                   entry
               ] =
                 ListeningSession.get(session.id).replays

        assert entry["replay_id"] == replay.id
        assert entry["url"] == @url
      end)
    end

    test "rejects a link that is not a YouTube video, without any lookup" do
      {session, replay} = setup_session(fn _, _ -> state(%{}) end)

      assert {:error, :invalid_url} = Sessions.attach_upload(session.id, replay.id, "https://www.twitch.tv/videos/1")
      assert upload(session, replay)["status"] == "pending"
    end

    test "rejects a video that is unknown or not public yet" do
      {session, replay} = setup_session(fn _, _ -> state(%{}) end)

      expect(YoutubeApi, :get_video, fn _ -> {:error, "YouTube API error: 404"} end)
      assert {:error, :video_not_found} = Sessions.attach_upload(session.id, replay.id, @url)

      expect(YoutubeApi, :get_video, fn _ -> {:ok, video(%{privacy: :private})} end)
      assert {:error, :video_not_found} = Sessions.attach_upload(session.id, replay.id, @url)
    end

    test "rejects a video from another channel and names it" do
      {session, replay} = setup_session(fn _, _ -> state(%{}) end)

      expect(YoutubeApi, :get_video, fn _ ->
        {:ok, video(%{channel_id: "UC" <> String.duplicate("z", 22), channel_title: "Someone Else"})}
      end)

      assert {:error, {:wrong_channel, "Someone Else"}} = Sessions.attach_upload(session.id, replay.id, @url)
      assert %{"status" => "pending"} = refute_found(session, replay)
    end

    test "rejects a video already attached to the session" do
      other = %{"label" => "edited", "url" => @url, "video_id" => "dQw4w9WgXcQ", "replay_id" => "other"}
      {session, replay} = setup_session(fn _, _ -> state(%{}) end, [other])
      expect(YoutubeApi, :get_video, fn _ -> {:ok, video()} end)

      assert {:error, :duplicate} = Sessions.attach_upload(session.id, replay.id, @url)
      assert other in ListeningSession.get(session.id).replays
      assert %{"status" => "pending"} = refute_found(session, replay)
    end

    test "refuses a replay that is already found or skipped" do
      {%{album_id: album_id}, _} = setup_session(fn _, _ -> state(%{}) end)

      for status <- ["found", "skipped"] do
        {session, replay} = setup_session(fn _, _ -> state(%{"status" => status}) end, [], album_id)
        expect(YoutubeApi, :get_video, fn _ -> {:ok, video()} end)

        assert {:error, :invalid_transition} = Sessions.attach_upload(session.id, replay.id, @url)
      end
    end
  end

  describe "unmark_upload/2" do
    test "rejects an auto match: the video is removed from the slot, no new job" do
      manual(fn ->
        found = %{"status" => "found", "url" => @url, "video_id" => "v1", "source" => "auto"}
        {session, replay} = setup_session(fn _, _ -> state(found) end)

        assert {:ok, _} = Sessions.unmark_upload(session.id, replay.id)

        assert %{"status" => "rejected", "job_id" => nil, "label" => "raw"} = refute_found(session, replay)
        assert all_enqueued(worker: CheckUploadWorker) == []
      end)
    end

    test "sends a manual entry back to pending with a new job" do
      manual(fn ->
        found = %{"status" => "found", "url" => @url, "video_id" => "v1", "source" => "manual"}
        {session, replay} = setup_session(fn _, _ -> state(found) end)

        assert {:ok, _} = Sessions.unmark_upload(session.id, replay.id)

        assert %{"status" => "pending", "job_id" => job_id} = refute_found(session, replay)
        assert job_state(job_id) == "available"
      end)
    end

    test "unmarks a slot that was linked without any tracking" do
      manual(fn ->
        {session, replay} = setup_session(fn _, _ -> %{"url" => @url, "video_id" => "v1", "source" => "manual"} end)
        assert ReplayVideo.status(upload(session, replay)) == "found"

        assert {:ok, _} = Sessions.unmark_upload(session.id, replay.id)

        assert %{"status" => "pending", "job_id" => job_id} = refute_found(session, replay)
        assert is_integer(job_id)
      end)
    end

    test "refuses a replay that is not found" do
      {session, replay} = setup_session(fn _, _ -> state(%{}) end)

      assert {:error, :invalid_transition} = Sessions.unmark_upload(session.id, replay.id)
    end
  end

  test "an action keeps the other entries of the session" do
    other = %{"replay_id" => "other", "label" => "edited"} |> Map.merge(state(%{"status" => "exhausted"}))
    free = %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/1"}
    {session, replay} = setup_session(fn _, _ -> state(%{}) end, [free, other])

    assert {:ok, _} = Sessions.skip_upload(session.id, replay.id)

    replays = ListeningSession.get(session.id).replays
    assert free in replays
    assert other in replays
  end
end
