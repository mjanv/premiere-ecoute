defmodule PremiereEcouteWeb.Sessions.SessionReplaysTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Youtube.Video

  @auto %{
    "label" => "raw",
    "url" => "https://www.youtube.com/watch?v=abc",
    "replay_id" => "7c1e0a52-0b52-4c43-8a3e-2f1c7b9e4d22",
    "video_id" => "abc",
    "youtube_channel_id" => "UCaaaaaaaaaaaaaaaaaaaaaa",
    "channel_title" => "Lanfeust Plays",
    "thumbnail_url" => "https://i.ytimg.com/vi/abc/hqdefault.jpg",
    "source" => "auto"
  }
  @legacy %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/123"}

  setup %{conn: conn} do
    user = user_fixture(%{role: :streamer})
    {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id"}}) |> Single.create()
    {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: single.id})
    {:ok, session} = ListeningSession.start(session)
    {:ok, session} = ListeningSession.stop(session)
    {:ok, session} = ListeningSession.update_replays(session, [@auto, @legacy])
    {:ok, _report} = Report.generate(session)

    %{conn: log_in_user(conn, user), user: user, session: session}
  end

  defp open(conn, user, session), do: live(conn, ~p"/sessions/#{user.username}/#{session.share_token}")

  test "shows the thumbnail and the YouTube channel of a replay", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = open(conn, user, session)

    assert has_element?(view, ~s(img[src="https://i.ytimg.com/vi/abc/hqdefault.jpg"]))
    assert has_element?(view, "a", "Lanfeust Plays")
  end

  test "falls back to the site of the link without a channel", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = open(conn, user, session)

    assert has_element?(view, "a", "Twitch VOD")
    assert has_element?(view, "a", "twitch.tv")
    refute has_element?(view, ~s(a[href="https://www.twitch.tv/videos/123"] img))
  end

  test "removes a row of the modal and saves without it", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = open(conn, user, session)

    render_click(view, "open_replays_modal")
    assert has_element?(view, ~s(#replays-modal input[name="replays[1][url]"]))

    view |> element(~s(#replays-modal button[phx-click="remove_replay_entry"][phx-value-index="1"])) |> render_click()
    refute has_element?(view, ~s(#replays-modal input[name="replays[1][url]"]))

    view
    |> form("#replays-modal form", %{"replays" => %{"0" => %{"label" => "raw", "url" => @auto["url"]}}})
    |> render_submit()

    assert ListeningSession.get(session.id).replays == [@auto]
  end

  test "keeps the details of an entry whose link did not change", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = open(conn, user, session)

    render_click(view, "open_replays_modal")

    view
    |> form("#replays-modal form", %{
      "replays" => %{
        "0" => %{"label" => "raw cut", "url" => @auto["url"]},
        "1" => %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/999"}
      }
    })
    |> render_submit()

    assert [first, second] = ListeningSession.get(session.id).replays
    assert first == Map.put(@auto, "label", "raw cut")
    assert second == %{"label" => "Twitch VOD", "url" => "https://www.twitch.tv/videos/999"}
  end

  test "looks up a link that changed and stores the same entry as the automatic check", %{
    conn: conn,
    user: user,
    session: session
  } do
    found = %Video{
      id: "9bZkp7q19f0",
      url: "https://www.youtube.com/watch?v=9bZkp7q19f0",
      channel_id: "UCbbbbbbbbbbbbbbbbbbbbbb",
      channel_title: "Lanfeust Highlights",
      thumbnail_url: "https://i.ytimg.com/vi/9bZkp7q19f0/hqdefault.jpg"
    }

    expect(YoutubeApi, :get_video, fn "9bZkp7q19f0" -> {:ok, found} end)
    {:ok, view, _html} = open(conn, user, session)

    render_click(view, "open_replays_modal")

    view
    |> form("#replays-modal form", %{
      "replays" => %{
        "0" => %{"label" => "raw", "url" => "https://www.youtube.com/watch?v=9bZkp7q19f0"},
        "1" => %{"label" => "Twitch VOD", "url" => @legacy["url"]}
      }
    })
    |> render_submit()

    assert [first, second] = ListeningSession.get(session.id).replays
    assert %{"video_id" => "9bZkp7q19f0", "channel_title" => "Lanfeust Highlights", "source" => "manual"} = first
    assert first["thumbnail_url"] == found.thumbnail_url
    assert second == @legacy
  end

  test "lets the streamer link an entry to one of their replays", %{conn: conn, user: user, session: session} do
    {:ok, user} =
      User.edit_user_profile(user, %{
        video_settings: %{channels: [%{label: "Main", youtube_channel_id: "UC" <> String.duplicate("a", 22)}]}
      })

    channel_id = hd(user.profile.video_settings.channels).id

    {:ok, user} =
      User.edit_user_profile(User.get!(user.id), %{video_settings: %{replays: [%{name: "raw", channel_id: channel_id}]}})

    [replay] = user.profile.video_settings.replays
    {:ok, view, _html} = open(log_in_user(conn, user), user, session)

    render_click(view, "open_replays_modal")
    assert has_element?(view, ~s(#replays-modal select option), "raw")

    view
    |> form("#replays-modal form", %{
      "replays" => %{
        "0" => %{"label" => "raw", "url" => @auto["url"], "replay_id" => replay.id},
        "1" => %{"label" => "Twitch VOD", "url" => @legacy["url"], "replay_id" => ""}
      }
    })
    |> render_submit()

    assert [%{"replay_id" => replay_id, "video_id" => "abc"}, second] = ListeningSession.get(session.id).replays
    assert replay_id == replay.id
    refute Map.has_key?(second, "replay_id")
  end

  describe "look for the missing replays" do
    setup %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      {:ok, user} =
        User.edit_user_profile(user, %{
          video_settings: %{channels: [%{label: "Main", youtube_channel_id: "UC" <> String.duplicate("a", 22)}]}
        })

      channel_id = hd(user.profile.video_settings.channels).id

      {:ok, user} =
        User.edit_user_profile(User.get!(user.id), %{
          video_settings: %{replays: [%{name: "raw", channel_id: channel_id}, %{name: "edited", channel_id: channel_id}]}
        })

      {:ok, album} = Album.create(album_fixture())
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)
      {:ok, session} = ListeningSession.stop(session)
      {:ok, _report} = Report.generate(session)

      %{conn: log_in_user(conn, user), user: user, session: session}
    end

    test "has a button for the streamer, before the edit button", %{conn: conn, user: user, session: session} do
      {:ok, view, html} = open(conn, user, session)

      assert has_element?(view, ~s(button[phx-click="sync_replays"]))
      assert :binary.match(html, "sync_replays") < :binary.match(html, "open_replays_modal")
    end

    test "has no button for a streamer without replays configured", %{conn: conn, session: session} do
      other = user_fixture(%{role: :streamer})
      {:ok, other_session} = ListeningSession.create(%{user_id: other.id, album_id: session.album_id})
      {:ok, other_session} = ListeningSession.start(other_session)
      {:ok, other_session} = ListeningSession.stop(other_session)
      {:ok, _report} = Report.generate(other_session)
      {:ok, view, _html} = open(log_in_user(conn, other), other, other_session)

      assert has_element?(view, ~s(button[phx-click="open_replays_modal"]))

      refute has_element?(view, ~s(button[phx-click="sync_replays"]))
    end

    test "has no button for a session that is not an album session", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_single"}}) |> Single.create()
      {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: single.id})
      {:ok, session} = ListeningSession.start(session)
      {:ok, session} = ListeningSession.stop(session)
      {:ok, _report} = Report.generate(session)
      {:ok, view, _html} = open(log_in_user(conn, user), user, session)

      refute has_element?(view, ~s(button[phx-click="sync_replays"]))
    end

    test "stores the replays it finds and says which", %{conn: conn, user: user, session: session} do
      found = %Video{
        id: "dQw4w9WgXcQ",
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        title: "Sample Artist - Sample Album",
        channel_id: "UC" <> String.duplicate("a", 22),
        channel_title: "Lanfeust Plays",
        privacy: :public,
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
      }

      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ -> {:ok, [found]} end)
      {:ok, view, _html} = open(conn, user, session)

      view |> element(~s(button[phx-click="sync_replays"])) |> render_click()
      html = render_async(view)

      assert html =~ "Found: "
      assert html =~ "Lanfeust Plays"
      assert length(ListeningSession.get(session.id).replays) == 2
    end

    test "says what is still missing when nothing matches", %{conn: conn, user: user, session: session} do
      expect(YoutubeApi, :get_channel_videos, 2, fn _, _ -> {:ok, []} end)
      {:ok, view, _html} = open(conn, user, session)

      view |> element(~s(button[phx-click="sync_replays"])) |> render_click()
      html = render_async(view)

      assert html =~ "Nothing found yet. Still missing: raw, edited"
      assert ListeningSession.get(session.id).replays == []
    end
  end
end
