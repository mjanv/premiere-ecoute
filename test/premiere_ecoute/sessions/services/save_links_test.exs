defmodule PremiereEcoute.Sessions.Services.SaveLinksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker

  @url "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  @video %{"url" => @url, "video_id" => "dQw4w9WgXcQ", "channel_title" => "Lanfeust Plays", "source" => "auto"}
  @free %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/1"}

  defp manual(fun), do: Oban.Testing.with_testing_mode(:manual, fun)

  defp slot(attrs) do
    Map.merge(
      %{
        "replay_id" => "r1",
        "label" => "raw",
        "status" => "pending",
        "job_id" => nil,
        "due_at" => "2026-10-03T10:00:00Z",
        "last_checked_at" => nil
      },
      attrs
    )
  end

  defp session(replays, album_id \\ nil) do
    user = user_fixture(%{role: :streamer})
    album_id = album_id || elem(Album.create(album_fixture()), 1).id
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album_id, status: :stopped, replays: replays})
    session
  end

  defp replays(session), do: ListeningSession.get(session.id).replays

  test "replaces the links, in order, and keeps the slots still looked for" do
    pending = slot(%{})
    session = session([@free, pending])

    assert {:ok, _} =
             ReplayVideo.save_links(session.id, [
               %{"label" => "Other", "url" => "https://www.twitch.tv/videos/2"},
               %{"label" => "", "url" => ""},
               @free
             ])

    assert [%{"label" => "Other"}, @free, ^pending] = replays(session)
  end

  test "a link claiming a pending slot settles it as found and cancels its job" do
    manual(fn ->
      session = session([])

      {:ok, job} =
        CheckUploadWorker.start(%{session_id: session.id, replay_id: "r1"}, schedule_in: 3600)

      {:ok, session} = session |> ListeningSession.changeset(%{replays: [slot(%{"job_id" => job.id})]}) |> Repo.update()

      row = Map.merge(@video, %{"label" => "raw", "replay_id" => "r1", "source" => "manual"})
      assert {:ok, _} = ReplayVideo.save_links(session.id, [row])

      assert [
               %{
                 "status" => "found",
                 "job_id" => nil,
                 "source" => "manual",
                 "url" => @url
               }
             ] =
               replays(session)

      assert Repo.get!(Oban.Job, job.id, prefix: "oban").state == "cancelled"
    end)
  end

  test "keeps the details of an unchanged link and drops them when the link changes" do
    found = slot(%{"status" => "found"}) |> Map.merge(@video)
    session = session([found])

    assert {:ok, _} = ReplayVideo.save_links(session.id, [%{found | "label" => "cut"}])
    assert [%{"label" => "cut", "video_id" => "dQw4w9WgXcQ", "status" => "found"}] = replays(session)

    changed = %{"label" => "raw", "url" => "https://www.twitch.tv/videos/9", "replay_id" => "r1"}
    assert {:ok, _} = ReplayVideo.save_links(session.id, [changed])
    assert [%{"url" => "https://www.twitch.tv/videos/9", "status" => "found"} = entry] = replays(session)
    refute Map.has_key?(entry, "video_id")
    refute Map.has_key?(entry, "channel_title")
  end

  test "removing an auto match rejects the slot, removing a manual one revives it" do
    manual(fn ->
      auto = slot(%{"status" => "found"}) |> Map.merge(@video)
      session = session([auto])

      assert {:ok, _} = ReplayVideo.save_links(session.id, [])
      assert [%{"status" => "rejected", "job_id" => nil, "replay_id" => "r1"} = entry] = replays(session)
      refute Map.has_key?(entry, "url")

      by_hand = slot(%{"status" => "found"}) |> Map.merge(%{@video | "source" => "manual"})
      session = session([by_hand], session.album_id)

      assert {:ok, _} = ReplayVideo.save_links(session.id, [])
      assert [%{"status" => "pending", "job_id" => job_id}] = replays(session)
      assert is_integer(job_id)
    end)
  end

  test "moving a link to another replay unmarks the first one and settles the second" do
    manual(fn ->
      found = slot(%{"status" => "found"}) |> Map.merge(@video)
      other = slot(%{"replay_id" => "r2", "label" => "edited"})
      session = session([found, other])

      assert {:ok, _} = ReplayVideo.save_links(session.id, [Map.merge(found, %{"replay_id" => "r2"})])

      replays = replays(session)
      assert %{"status" => "found", "url" => @url} = ReplayVideo.slot(replays, "r2")
      assert %{"status" => "rejected"} = r1 = ReplayVideo.slot(replays, "r1")
      refute Map.has_key?(r1, "url")
    end)
  end

  test "keeps an untracked link of a replay that has no slot" do
    linked = %{"label" => "raw", "url" => @url, "replay_id" => "r9", "source" => "manual"}
    session = session([linked])

    assert {:ok, _} = ReplayVideo.save_links(session.id, [linked])
    assert replays(session) == [linked]

    assert {:ok, _} = ReplayVideo.save_links(session.id, [])
    assert replays(session) == []
  end

  test "refuses two links for the same replay and writes nothing" do
    pending = slot(%{})
    session = session([@free, pending])

    rows = [
      %{"label" => "a", "url" => @url, "replay_id" => "r1"},
      %{"label" => "b", "url" => "https://www.twitch.tv/videos/2", "replay_id" => "r1"}
    ]

    assert {:error, :duplicate_replay} = ReplayVideo.save_links(session.id, rows)
    assert replays(session) == [@free, pending]
  end

  test "fails for an unknown session" do
    assert {:error, :not_found} = ReplayVideo.save_links(0, [])
  end
end
