defmodule PremiereEcouteWeb.Sessions.SessionsLiveReplaysTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Workers.CheckUploadNowWorker
  alias PremiereEcoute.Youtube.Video

  @channel_id "UC" <> String.duplicate("a", 22)

  defp slot(replay_id, label, status, attrs \\ %{}) do
    Map.merge(%{"replay_id" => replay_id, "label" => label, "status" => status, "job_id" => nil}, attrs)
  end

  setup %{conn: conn} do
    user = user_fixture(%{role: :streamer})

    {:ok, user} =
      User.edit_user_profile(user, %{video_settings: %{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}})

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{video_settings: %{replays: [%{name: "raw", channel_id: channel_id}]}})

    [replay] = user.profile.video_settings.replays
    {:ok, album} = Album.create(album_fixture())

    %{conn: log_in_user(conn, user), user: user, replay: replay, album_id: album.id}
  end

  defp session(user, album_id, replays) do
    {:ok, session} =
      ListeningSession.create(%{
        user_id: user.id,
        album_id: album_id,
        status: :stopped,
        ended_at: DateTime.add(DateTime.utc_now(:second), -2, :hour),
        replays: replays
      })

    session
  end

  # Oban runs inline in tests except in the process that asks for the manual mode. The LiveView process is not the
  # test process, so it asks for it itself.
  defp manual_oban(view) do
    :sys.replace_state(view.pid, fn state ->
      Process.put(:oban_testing, :manual)
      state
    end)
  end

  defp row(session, replay_id), do: "#replay-#{session.id}-#{replay_id}"

  defp click(view, session, replay_id, action) do
    view
    |> element(~s(#{row(session, replay_id)} button[phx-value-action="#{action}"]))
    |> render_click()
  end

  defp replays(session), do: ListeningSession.get(session.id).replays

  test "shows each replay with its status and the actions that apply", %{conn: conn, user: user, album_id: album_id} do
    found = slot("f", "raw", "found", %{"url" => "https://youtu.be/abc", "channel_title" => "Lanfeust Plays", "source" => "auto"})

    session =
      session(user, album_id, [
        found,
        slot("p", "edited", "pending"),
        slot("e", "short", "exhausted"),
        slot("r", "clip", "rejected"),
        slot("s", "extra", "skipped")
      ])

    {:ok, view, html} = live(conn, ~p"/sessions")

    assert has_element?(view, "#{row(session, "f")} a[href=\"https://youtu.be/abc\"]", "Lanfeust Plays")

    for {id, badge, actions} <- [
          {"f", "Found", ~w(unmark)},
          {"p", "Missing", ~w(check paste skip)},
          {"e", "not found after all checks", ~w(retry paste skip)},
          {"r", "match rejected", ~w(paste skip)},
          {"s", "Skipped", ~w(unskip)}
        ] do
      assert has_element?(view, row(session, id), badge)

      shown =
        view
        |> element(row(session, id))
        |> render()
        |> then(&Regex.scan(~r/phx-value-action="(\w+)"/, &1))
        |> Enum.map(&List.last/1)

      assert Enum.sort(shown) == Enum.sort(actions), id
    end

    for id <- ~w(p e r), do: assert(has_element?(view, row(session, id), "Missing"))
    refute has_element?(view, row(session, "f"), "Missing")
    refute has_element?(view, row(session, "s"), "Missing")

    assert html =~ "3 replays missing"
  end

  test "shows the title of a found video, with its channel, or the channel alone without a title", %{
    conn: conn,
    user: user,
    album_id: album_id
  } do
    titled =
      slot("t", "raw", "found", %{
        "url" => "https://youtu.be/abc",
        "title" => "PREMIÈRE ÉCOUTE : \"Bass Persuades\"",
        "channel_title" => "Lanfeust Plays"
      })

    untitled = slot("u", "edited", "found", %{"url" => "https://youtu.be/def", "channel_title" => "Lanfeust Plays"})
    session = session(user, album_id, [titled, untitled])

    {:ok, view, _html} = live(conn, ~p"/sessions")

    assert has_element?(view, "#{row(session, "t")} a[href=\"https://youtu.be/abc\"]", "Bass Persuades")
    assert has_element?(view, row(session, "t"), "Lanfeust Plays")
    assert has_element?(view, "#{row(session, "u")} a[href=\"https://youtu.be/def\"]", "Lanfeust Plays")
  end

  test "links the card to the public page of the session", %{conn: conn, user: user, album_id: album_id} do
    session = session(user, album_id, [])

    {:ok, view, _html} = live(conn, ~p"/sessions")

    expected = "/sessions/#{user.username}/#{session.share_token}?return_to=%2Fsessions"
    assert has_element?(view, ~s(#sessions-#{session.id} a[href="#{expected}"]))
  end

  test "shows nothing for a session without replays and no chip", %{conn: conn, user: user, album_id: album_id} do
    session = session(user, album_id, [%{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/1"}])

    {:ok, view, html} = live(conn, ~p"/sessions")

    refute has_element?(view, "#replays-#{session.id}")
    refute html =~ "replay missing"
    refute html =~ "replays missing"
  end

  test "counts a replay being looked for as missing, without the amber border", %{
    conn: conn,
    user: user,
    album_id: album_id
  } do
    session(user, album_id, [slot("p", "raw", "pending")])

    {:ok, _view, html} = live(conn, ~p"/sessions")

    assert html =~ "1 replay missing"
    refute html =~ "border-amber-500/50"
  end

  test "marks the card when a replay needs the streamer", %{conn: conn, user: user, album_id: album_id} do
    session(user, album_id, [slot("e", "short", "exhausted")])

    {:ok, _view, html} = live(conn, ~p"/sessions")

    assert html =~ "1 replay missing"
    assert html =~ "border-amber-500/50"
  end

  test "skips, unskips and retries a replay", %{conn: conn, user: user, album_id: album_id} do
    Oban.Testing.with_testing_mode(:manual, fn ->
      session = session(user, album_id, [slot("e", "short", "exhausted")])
      {:ok, view, _html} = live(conn, ~p"/sessions")
      manual_oban(view)

      click(view, session, "e", "skip")
      assert has_element?(view, row(session, "e"), "Skipped")
      assert [%{"status" => "skipped"}] = replays(session)

      click(view, session, "e", "unskip")
      assert has_element?(view, row(session, "e"), "Missing")
      assert [%{"status" => "pending", "job_id" => job_id}] = replays(session)
      assert is_integer(job_id)

      other = session(user, album_id, [slot("e", "short", "exhausted")])
      render_click(view, "replay_action", %{"action" => "retry", "session_id" => other.id, "replay_id" => "e"})
      assert [%{"status" => "pending"}] = replays(other)
    end)
  end

  test "unmarks an auto match as rejected", %{conn: conn, user: user, album_id: album_id} do
    found = slot("f", "raw", "found", %{"url" => "https://youtu.be/abc", "video_id" => "abc", "source" => "auto"})
    session = session(user, album_id, [found])
    {:ok, view, _html} = live(conn, ~p"/sessions")

    click(view, session, "f", "unmark")

    assert has_element?(view, row(session, "f"), "Missing")
    assert has_element?(view, row(session, "f"), "match rejected")
    assert [%{"status" => "rejected"} = entry] = replays(session)
    refute Map.has_key?(entry, "url")
  end

  test "links a replay with a pasted YouTube link", %{conn: conn, user: user, album_id: album_id, replay: replay} do
    session = session(user, album_id, [slot(replay.id, "raw", "exhausted")])
    {:ok, view, _html} = live(conn, ~p"/sessions")

    click(view, session, replay.id, "paste")
    assert has_element?(view, "#{row(session, replay.id)} form input[name=url]")

    view |> form("#{row(session, replay.id)} form", %{"url" => "https://www.twitch.tv/videos/1"}) |> render_submit()
    assert has_element?(view, row(session, replay.id), "This is not a YouTube video link")
    assert [%{"status" => "exhausted"}] = replays(session)

    video = %Video{
      id: "dQw4w9WgXcQ",
      url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      title: "PREMIÈRE ÉCOUTE : Bass Persuades",
      channel_id: @channel_id,
      channel_title: "Lanfeust Plays",
      privacy: :public
    }

    expect(YoutubeApi, :get_video, fn "dQw4w9WgXcQ" -> {:ok, video} end)

    view
    |> form("#{row(session, replay.id)} form", %{"url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"})
    |> render_submit()

    refute has_element?(view, "#{row(session, replay.id)} form")
    assert has_element?(view, row(session, replay.id), "Found")
    assert has_element?(view, row(session, replay.id), "PREMIÈRE ÉCOUTE : Bass Persuades")
    assert has_element?(view, row(session, replay.id), "Lanfeust Plays")
    assert [%{"status" => "found", "source" => "manual", "title" => "PREMIÈRE ÉCOUTE : Bass Persuades"}] = replays(session)
  end

  test "names the channel of a video from another channel", %{conn: conn, user: user, album_id: album_id, replay: replay} do
    session = session(user, album_id, [slot(replay.id, "raw", "exhausted")])
    {:ok, view, _html} = live(conn, ~p"/sessions")
    click(view, session, replay.id, "paste")

    expect(YoutubeApi, :get_video, fn _ ->
      {:ok,
       %Video{id: "dQw4w9WgXcQ", channel_id: "UC" <> String.duplicate("z", 22), channel_title: "Someone Else", privacy: :public}}
    end)

    view |> form("#{row(session, replay.id)} form", %{"url" => "https://youtu.be/dQw4w9WgXcQ"}) |> render_submit()

    assert has_element?(view, row(session, replay.id), "This video is on Someone Else")
  end

  test "cancel closes the link form, and opening another closes the first", %{conn: conn, user: user, album_id: album_id} do
    session = session(user, album_id, [slot("a", "raw", "exhausted"), slot("b", "edited", "exhausted")])
    {:ok, view, _html} = live(conn, ~p"/sessions")

    click(view, session, "a", "paste")
    assert has_element?(view, "#{row(session, "a")} form")

    click(view, session, "b", "paste")
    refute has_element?(view, "#{row(session, "a")} form")
    assert has_element?(view, "#{row(session, "b")} form")

    click(view, session, "b", "cancel")
    refute has_element?(view, "#{row(session, "b")} form")
  end

  test "shows one row, and one form, per replay even when entries share a replay id", %{
    conn: conn,
    user: user,
    album_id: album_id
  } do
    session =
      session(user, album_id, [
        slot("r", "raw", "exhausted"),
        %{"replay_id" => "r", "label" => "edited", "url" => "https://youtu.be/abc"},
        %{"replay_id" => "r", "label" => "test", "url" => "https://youtu.be/def"}
      ])

    {:ok, view, _html} = live(conn, ~p"/sessions")

    assert view |> element("#replays-#{session.id}") |> render() |> String.split("phx-value-replay_id=\"r\"") |> length() > 1
    refute has_element?(view, row(session, "r") <> " a")

    click(view, session, "r", "paste")

    assert view |> element("#replays-#{session.id}") |> render() |> String.split("<form") |> length() == 2
  end

  test "ignores an action on the session of someone else", %{conn: conn, album_id: album_id} do
    other = user_fixture(%{role: :streamer})
    session = session(other, album_id, [slot("e", "short", "exhausted")])
    {:ok, view, _html} = live(conn, ~p"/sessions")

    render_click(view, "replay_action", %{"action" => "skip", "session_id" => session.id, "replay_id" => "e"})

    assert [%{"status" => "exhausted"}] = replays(session)
  end

  test "refreshes the card when a scheduled check finds the video", %{conn: conn, user: user, album_id: album_id, replay: replay} do
    session = session(user, album_id, [slot(replay.id, "raw", "pending")])
    {:ok, view, _html} = live(conn, ~p"/sessions")
    assert has_element?(view, row(session, replay.id), "Missing")

    video = %Video{
      id: "abc",
      url: "https://www.youtube.com/watch?v=abc",
      title: "Sample Artist - Sample Album",
      channel_id: @channel_id,
      channel_title: "Lanfeust Plays",
      privacy: :public
    }

    expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, [video]} end)

    assert :ok =
             perform_job(PremiereEcoute.Sessions.Workers.CheckUploadWorker, %{
               session_id: session.id,
               replay_id: replay.id,
               iteration: 3
             })

    assert has_element?(view, row(session, replay.id), "Found")
    assert has_element?(view, row(session, replay.id), "Sample Artist - Sample Album")
  end

  describe "check now" do
    setup %{user: user, album_id: album_id, replay: replay} do
      session = session(user, album_id, [slot(replay.id, "raw", "pending")])
      %{session: session}
    end

    defp check_button(session, replay), do: ~s(#{row(session, replay.id)} button[phx-value-action="check"])

    defp run_check(session, replay),
      do: perform_job(CheckUploadNowWorker, %{session_id: session.id, replay_id: replay.id})

    test "disables the button while the job runs, then shows a video found", %{
      conn: conn,
      session: session,
      replay: replay
    } do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, view, _html} = live(conn, ~p"/sessions")
        manual_oban(view)

        click(view, session, replay.id, "check")

        assert_enqueued worker: CheckUploadNowWorker, args: %{session_id: session.id, replay_id: replay.id}
        assert has_element?(view, check_button(session, replay) <> "[disabled]", "Checking...")

        video = %Video{
          id: "abc",
          url: "https://www.youtube.com/watch?v=abc",
          title: "Sample Artist - Sample Album",
          channel_id: @channel_id,
          channel_title: "Lanfeust Plays",
          privacy: :public
        }

        expect(YoutubeApi, :get_channel_videos, fn @channel_id, _ -> {:ok, [video]} end)
        assert :ok = run_check(session, replay)

        refute has_element?(view, check_button(session, replay))
        assert has_element?(view, row(session, replay.id), "Found")
        assert has_element?(view, row(session, replay.id), "Lanfeust Plays")
      end)
    end

    test "gives the button back when the video is not found, the replay staying pending", %{
      conn: conn,
      session: session,
      replay: replay
    } do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, view, _html} = live(conn, ~p"/sessions")
        manual_oban(view)
        click(view, session, replay.id, "check")
        assert has_element?(view, check_button(session, replay) <> "[disabled]")

        expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:ok, []} end)
        assert :ok = run_check(session, replay)

        assert has_element?(view, check_button(session, replay), "Check now")
        refute has_element?(view, check_button(session, replay) <> "[disabled]")
        assert has_element?(view, row(session, replay.id), "Missing")
      end)
    end

    test "gives the button back when the job never answers", %{conn: conn, session: session, replay: replay} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, view, _html} = live(conn, ~p"/sessions")
        manual_oban(view)
        click(view, session, replay.id, "check")
        assert has_element?(view, check_button(session, replay) <> "[disabled]")

        send(view.pid, {:check_timeout, session.id, replay.id})

        refute has_element?(view, check_button(session, replay) <> "[disabled]")
        assert has_element?(view, check_button(session, replay), "Check now")
      end)
    end

    test "does not ask twice while a check is running", %{conn: conn, session: session, replay: replay} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, view, _html} = live(conn, ~p"/sessions")
        manual_oban(view)
        click(view, session, replay.id, "check")

        render_click(view, "replay_action", %{
          "action" => "check",
          "session_id" => session.id,
          "replay_id" => replay.id
        })

        assert length(all_enqueued(worker: CheckUploadNowWorker)) == 1
      end)
    end
  end
end
