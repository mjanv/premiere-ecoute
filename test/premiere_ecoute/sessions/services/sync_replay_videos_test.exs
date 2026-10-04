defmodule PremiereEcoute.Sessions.Services.SyncReplayVideosTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker
  alias PremiereEcoute.Youtube.Video

  @channel_id "UC" <> String.duplicate("a", 22)

  defp pending(attrs \\ %{}) do
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

  defp setup_session(attrs \\ %{}) do
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

    {:ok, session} =
      ListeningSession.create(
        Map.merge(
          %{
            user_id: user.id,
            album_id: album.id,
            status: :stopped,
            ended_at: DateTime.add(DateTime.utc_now(:second), -2, :hour)
          },
          attrs
        )
      )

    {session, raw, edited}
  end

  defp video(title) do
    %Video{
      id: "vid#{System.unique_integer([:positive])}",
      url: "https://www.youtube.com/watch?v=abc",
      title: title,
      channel_id: @channel_id,
      channel_title: "Lanfeust Plays",
      published_at: "2026-10-04T10:00:00Z",
      privacy: :public,
      thumbnail_url: "https://i.ytimg.com/vi/abc/hq.jpg"
    }
  end

  describe "sync_replay_videos/1" do
    test "stores the videos found for the missing replays" do
      {session, raw, edited} = setup_session()
      expect(YoutubeApi, :get_channel_videos, 2, fn @channel_id, _ -> {:ok, [video("Sample Artist - Sample Album")]} end)

      assert {:ok, %{found: found, missing: [], failed: []}} = ReplayVideo.sync_replay_videos(session.id)
      assert Enum.sort(Enum.map(found, & &1.id)) == Enum.sort([raw.id, edited.id])

      assert [%{"source" => "auto", "channel_title" => "Lanfeust Plays"}, _] = ListeningSession.get(session.id).replays
    end

    test "reports the replays that are still missing and leaves them alone" do
      {session, _raw, _edited} = setup_session(%{options: %{"autostart" => true}})
      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ -> {:ok, [video("Something else")]} end)

      assert {:ok, %{found: [], missing: [_, _], failed: []}} = ReplayVideo.sync_replay_videos(session.id)

      reloaded = ListeningSession.get(session.id)
      assert reloaded.replays == []
      assert reloaded.options == %{"autostart" => true}
    end

    test "reports the replays whose lookup failed" do
      {session, _raw, _edited} = setup_session()
      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ -> {:error, "YouTube API error: 403"} end)

      assert {:ok, %{found: [], missing: [], failed: [_, _]}} = ReplayVideo.sync_replay_videos(session.id)
    end

    test "only looks for the replays without an entry, and leaves the entries alone" do
      {session, raw, edited} = setup_session()
      existing = %{"label" => "raw", "url" => "https://youtu.be/manual", "replay_id" => raw.id, "source" => "manual"}
      {:ok, session} = ListeningSession.update_replays(session, [existing])
      expect(YoutubeApi, :get_channel_videos, 1, fn _, _ -> {:ok, [video("Sample Artist - Sample Album")]} end)

      assert {:ok, %{found: [%{id: found_id}], missing: [], failed: []}} = ReplayVideo.sync_replay_videos(session.id)
      assert found_id == edited.id
      assert [^existing, %{"replay_id" => replay_id}] = ListeningSession.get(session.id).replays
      assert replay_id == edited.id
    end

    test "settles the pending and exhausted slots it finds, and cancels the job of a pending one" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {session, raw, edited} = setup_session()

        {:ok, job} =
          CheckUploadWorker.start(%{session_id: session.id, replay_id: raw.id}, schedule_in: 3600)

        slots = [
          Map.merge(%{"replay_id" => raw.id, "label" => "raw"}, pending(%{"job_id" => job.id})),
          Map.merge(%{"replay_id" => edited.id, "label" => "edited"}, pending(%{"status" => "exhausted"}))
        ]

        {:ok, session} = session |> ListeningSession.changeset(%{replays: slots}) |> PremiereEcoute.Repo.update()
        expect(YoutubeApi, :get_channel_videos, 2, fn _, _ -> {:ok, [video("Sample Artist - Sample Album")]} end)

        assert {:ok, %{found: [_, _]}} = ReplayVideo.sync_replay_videos(session.id)

        replays = ListeningSession.get(session.id).replays
        assert length(replays) == 2

        for replay <- [raw, edited] do
          assert %{
                   "status" => "found",
                   "job_id" => nil,
                   "source" => "auto",
                   "url" => _
                 } =
                   ReplayVideo.slot(replays, replay.id)
        end

        assert PremiereEcoute.Repo.get!(Oban.Job, job.id, prefix: "oban").state == "cancelled"
      end)
    end

    test "leaves the skipped and rejected slots alone" do
      {session, raw, edited} = setup_session()

      slots = [
        Map.merge(%{"replay_id" => raw.id, "label" => "raw"}, pending(%{"status" => "skipped"})),
        Map.merge(%{"replay_id" => edited.id, "label" => "edited"}, pending(%{"status" => "rejected"}))
      ]

      {:ok, session} = session |> ListeningSession.changeset(%{replays: slots}) |> PremiereEcoute.Repo.update()

      assert {:ok, %{found: [], missing: [], failed: []}} = ReplayVideo.sync_replay_videos(session.id)
      assert ListeningSession.get(session.id).replays == slots
    end

    test "does not accept a session that is not an ended album session" do
      {running, _, _} = setup_session(%{ended_at: nil})

      assert {:error, :session_not_valid} = ReplayVideo.sync_replay_videos(running.id)
      assert {:error, :not_found} = ReplayVideo.sync_replay_videos(0)
    end
  end
end
