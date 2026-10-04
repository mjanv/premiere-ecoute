defmodule PremiereEcoute.Sessions.Services.ForgetReplayTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker

  @channel_id "UC" <> String.duplicate("a", 22)
  @free %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/1"}

  defp manual(fun), do: Oban.Testing.with_testing_mode(:manual, fun)

  defp streamer(replay_names) do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{video_settings: %{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}})

    channel_id = hd(user.profile.video_settings.channels).id
    replays = for name <- replay_names, do: %{name: name, channel_id: channel_id}
    {:ok, user} = User.edit_user_profile(User.get!(user.id), %{video_settings: %{replays: replays}})
    user
  end

  defp session(user, replays, album_id \\ nil) do
    album_id = album_id || elem(Album.create(album_fixture()), 1).id

    {:ok, session} =
      ListeningSession.create(%{user_id: user.id, album_id: album_id, status: :stopped, replays: replays})

    session
  end

  defp pending(replay_id, label, job_id \\ nil),
    do: %{
      "replay_id" => replay_id,
      "label" => label,
      "status" => "pending",
      "job_id" => job_id,
      "due_at" => "2026-10-03T10:00:00Z"
    }

  defp found(replay_id, label) do
    %{
      "replay_id" => replay_id,
      "label" => label,
      "status" => "found",
      "job_id" => nil,
      "due_at" => "2026-10-03T10:00:00Z",
      "last_checked_at" => "2026-10-04T10:00:00Z",
      "url" => "https://www.youtube.com/watch?v=abc",
      "video_id" => "abc",
      "title" => "Kid A",
      "channel_title" => "Lanfeust Plays",
      "source" => "auto"
    }
  end

  defp replays(session), do: ListeningSession.get(session.id).replays

  test "removes a slot still being looked for and cancels its job" do
    manual(fn ->
      user = streamer(["raw", "edited"])
      [raw, edited] = user.profile.video_settings.replays
      session = session(user, [])

      {:ok, job} = CheckUploadWorker.start(%{session_id: session.id, replay_id: raw.id, iteration: 3}, schedule_in: 3600)

      {:ok, _} =
        session
        |> ListeningSession.changeset(%{replays: [pending(raw.id, "raw", job.id), pending(edited.id, "edited")]})
        |> Repo.update()

      assert :ok = ReplayVideo.forget_replay(user.id, raw.id)

      assert [%{"replay_id" => replay_id}] = replays(session)
      assert replay_id == edited.id
      assert Repo.get!(Oban.Job, job.id, prefix: "oban").state == "cancelled"
    end)
  end

  test "turns a found slot into a plain link that keeps its video" do
    user = streamer(["raw"])
    [raw] = user.profile.video_settings.replays
    session = session(user, [found(raw.id, "raw")])

    assert :ok = ReplayVideo.forget_replay(user.id, raw.id)

    assert [link] = replays(session)

    assert link == %{
             "label" => "raw",
             "url" => "https://www.youtube.com/watch?v=abc",
             "video_id" => "abc",
             "title" => "Kid A",
             "channel_title" => "Lanfeust Plays",
             "source" => "auto"
           }

    assert ReplayVideo.slots(ListeningSession.get(session.id)) == []
  end

  test "leaves the other replays, the free links and other users alone" do
    user = streamer(["raw", "edited"])
    [raw, edited] = user.profile.video_settings.replays
    keep = [@free, pending(edited.id, "edited")]
    session = session(user, keep ++ [pending(raw.id, "raw")])

    other = user_fixture(%{role: :streamer})
    other_session = session(other, [pending(raw.id, "raw")], session.album_id)

    assert :ok = ReplayVideo.forget_replay(user.id, raw.id)

    assert replays(session) == keep
    assert [%{"replay_id" => replay_id}] = replays(other_session)
    assert replay_id == raw.id
  end

  test "does nothing for a replay no session knows" do
    user = streamer(["raw"])
    session = session(user, [@free])

    assert :ok = ReplayVideo.forget_replay(user.id, Ecto.UUID.generate())
    assert replays(session) == [@free]
  end

  test "is done when a replay is removed from the settings" do
    user = streamer(["raw", "edited"])
    [raw, edited] = user.profile.video_settings.replays
    session = session(user, [found(raw.id, "raw"), pending(edited.id, "edited"), @free])

    {:ok, updated} =
      User.edit_user_profile(User.get!(user.id), %{
        video_settings: %{replays: [%{id: raw.id, name: "raw", channel_id: raw.channel_id}]}
      })

    assert [%{id: kept_id}] = updated.profile.video_settings.replays
    assert kept_id == raw.id
    assert [%{"replay_id" => ^kept_id, "status" => "found"}, @free] = replays(session)
  end

  test "is not done when the settings keep every replay" do
    user = streamer(["raw"])
    [raw] = user.profile.video_settings.replays
    session = session(user, [pending(raw.id, "raw")])

    {:ok, _} =
      User.edit_user_profile(User.get!(user.id), %{
        video_settings: %{show_name: "Other name", replays: [%{id: raw.id, name: "raw", channel_id: raw.channel_id}]}
      })

    assert [%{"replay_id" => replay_id, "status" => "pending"}] = replays(session)
    assert replay_id == raw.id
  end
end
