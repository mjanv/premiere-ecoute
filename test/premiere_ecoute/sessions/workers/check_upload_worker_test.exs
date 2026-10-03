defmodule PremiereEcoute.Sessions.Workers.CheckUploadWorkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
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
        "iterations" => 0,
        "max_iterations" => 3,
        "interval_hours" => 24,
        "last_checked_at" => nil,
        "next_check_at" => due_at,
        "last_failure" => nil
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

    uploads = for {replay, state} <- Enum.zip([raw, edited], states), state != nil, into: %{}, do: {replay.id, state}

    {:ok, session} =
      ListeningSession.create(%{
        user_id: user.id,
        album_id: album.id,
        status: :stopped,
        ended_at: DateTime.add(DateTime.utc_now(:second), -2, :hour),
        options: %{"uploads" => uploads}
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

  defp run(session, replay) do
    Oban.Testing.with_testing_mode(:manual, fn ->
      result = perform_job(CheckUploadWorker, %{session_id: session.id, replay_id: replay.id})
      {result, all_enqueued(worker: CheckUploadWorker)}
    end)
  end

  defp uploads(session), do: ListeningSession.get(session.id).options["uploads"]

  describe "perform/1" do
    test "stores the found video and finishes" do
      {session, raw, _edited} = setup_session([state(), state()])
      expect(YoutubeApi, :get_channel_videos, fn @channel_id, _ -> {:ok, [video()]} end)

      assert {:ok, []} = run(session, raw)

      assert %{"status" => "found", "next_check_at" => nil, "job_id" => nil} = uploads(session)[raw.id]

      assert [%{"replay_id" => replay_id, "thumbnail_url" => "https://i.ytimg.com/vi/abc/hq.jpg", "source" => "auto"}] =
               ListeningSession.get(session.id).replays

      assert replay_id == raw.id
    end

    test "counts a failed iteration and inserts the next check" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      assert {:ok, [job]} = run(session, raw)
      assert_in_delta DateTime.diff(job.scheduled_at, DateTime.utc_now()), 24 * 3600, 5
      assert job.args == %{"session_id" => session.id, "replay_id" => raw.id}

      assert %{"status" => "pending", "iterations" => 1, "last_failure" => "not_found", "job_id" => job_id} =
               uploads(session)[raw.id]

      assert job_id == job.id
    end

    test "records an API error as such" do
      {session, raw, _edited} = setup_session([state(), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:error, "YouTube API error: 403"} end)

      assert {:ok, [_job]} = run(session, raw)

      assert %{"iterations" => 1, "last_failure" => "api_error"} = uploads(session)[raw.id]
    end

    test "exhausts the replay on its last iteration" do
      {session, raw, _edited} = setup_session([state(%{"iterations" => 2}), nil])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)

      assert {:ok, []} = run(session, raw)

      assert %{"status" => "exhausted", "iterations" => 3, "next_check_at" => nil, "job_id" => nil} = uploads(session)[raw.id]
    end

    test "leaves the other replays untouched" do
      other = state(%{"iterations" => 1})
      {session, raw, edited} = setup_session([state(), other])
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, [video()]} end)

      assert {:ok, []} = run(session, raw)

      assert uploads(session)[edited.id] == other
    end

    test "does nothing before the next check is due" do
      later = DateTime.to_iso8601(DateTime.add(DateTime.utc_now(:second), 5, :hour))
      pending = state(%{"next_check_at" => later})
      {session, raw, _edited} = setup_session([pending, nil])

      assert {:ok, []} = run(session, raw)
      assert uploads(session)[raw.id] == pending
    end

    test "cancels when the replay is not pending anymore" do
      skipped = state(%{"status" => "skipped", "next_check_at" => nil})
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
end
