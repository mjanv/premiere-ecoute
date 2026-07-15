defmodule PremiereEcouteWeb.Sessions.SessionSelectionLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Hammox
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.Video.YoutubeApi

  setup :verify_on_exit!

  setup do
    user = user_fixture(%{role: :streamer, spotify: %{user_id: "spotify_user_123", username: "spotifyuser"}})
    {:ok, user: user}
  end

  describe "clip source button" do
    test "is disabled when the listening_session_clip flag is off", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      assert has_element?(view, "button[disabled][phx-value-source='clip']")
    end

    test "is enabled and selectable when the listening_session_clip flag is on", %{conn: conn, user: user} do
      FunWithFlags.enable(:listening_session_clip)
      on_exit(fn -> FunWithFlags.disable(:listening_session_clip) end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      refute has_element?(view, "button[disabled][phx-value-source='clip']")

      view |> element("button[phx-value-source='clip']") |> render_click()

      assert has_element?(view, "#step-2")
    end
  end

  describe "clip wizard flow" do
    setup do
      FunWithFlags.enable(:listening_session_clip)
      on_exit(fn -> FunWithFlags.disable(:listening_session_clip) end)
      :ok
    end

    test "search, select, and prepare a clip session", %{conn: conn, user: user} do
      expect(YoutubeApi.Mock, :search_track_videos, fn "one more time" ->
        {:ok,
         [
           %{
             id: "yt_abc123",
             url: "https://www.youtube.com/watch?v=yt_abc123",
             title: "One More Time (Official Video)",
             channel_title: "Sample Artist",
             published_at: "2020-01-01T00:00:00Z",
             thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/hqdefault.jpg"
           }
         ]}
      end)

      expect(YoutubeApi.Mock, :get_video, fn "yt_abc123" ->
        {:ok,
         %{
           id: "yt_abc123",
           title: "One More Time (Official Video)",
           channel_title: "Sample Artist",
           duration: "PT3M20S",
           thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
         }}
      end)

      single = single_fixture(%{name: "One More Time"})
      expect(SpotifyApi.Mock, :search_singles, fn _query -> {:ok, [single]} end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      view |> element("button[phx-value-source='clip']") |> render_click()

      view
      |> form("#clip-search-form", %{"query" => "one more time"})
      |> render_change()

      render_async(view)

      view |> element("[phx-click='select_clip_video'][phx-value-video_id='yt_abc123']") |> render_click()

      view
      |> element("form[phx-change='vote_options_preset_change']")
      |> render_change(%{"preset" => "0-10"})

      {:error, {:live_redirect, %{to: to}}} =
        view |> element("[phx-click='prepare_session']") |> render_click()

      assert to =~ "/dashboard"
    end

    test "shows an error flash when the YouTube search fails", %{conn: conn, user: user} do
      expect(YoutubeApi.Mock, :search_track_videos, fn "broken query" -> {:error, :timeout} end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      view |> element("button[phx-value-source='clip']") |> render_click()

      view
      |> form("#clip-search-form", %{"query" => "broken query"})
      |> render_change()

      html = render_async(view)

      assert html =~ "Video search failed"
    end

    test "clicking a stale search result (no longer in the current results) is a no-op", %{conn: conn, user: user} do
      expect(YoutubeApi.Mock, :search_track_videos, fn "one more time" ->
        {:ok,
         [
           %{
             id: "yt_abc123",
             url: "https://www.youtube.com/watch?v=yt_abc123",
             title: "One More Time (Official Video)",
             channel_title: "Sample Artist",
             published_at: "2020-01-01T00:00:00Z",
             thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/hqdefault.jpg"
           },
           %{
             id: "yt_def456",
             url: "https://www.youtube.com/watch?v=yt_def456",
             title: "One More Time (Live)",
             channel_title: "Sample Artist Live",
             published_at: "2020-01-01T00:00:00Z",
             thumbnail_url: "https://i.ytimg.com/vi/yt_def456/hqdefault.jpg"
           }
         ]}
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      view |> element("button[phx-value-source='clip']") |> render_click()

      view
      |> form("#clip-search-form", %{"query" => "one more time"})
      |> render_change()

      render_async(view)

      render_click(view, "select_clip_video", %{"video_id" => "yt_stale_id_not_in_results"})

      refute has_element?(view, "[phx-click='prepare_session']")
      refute has_element?(view, "#selected-clip-video")
    end

    test "selecting a video id with an empty result list (no search performed yet) is a no-op", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      view |> element("button[phx-value-source='clip']") |> render_click()

      html = render_click(view, "select_clip_video", %{"video_id" => "yt_abc123"})

      refute has_element?(view, "[phx-click='prepare_session']")
      refute has_element?(view, "#selected-clip-video")
      assert html =~ "Search YouTube videos"
    end

    test "selecting a video while a search is still in flight is a no-op", %{conn: conn, user: user} do
      test_pid = self()

      stub(YoutubeApi.Mock, :search_track_videos, fn "one more time" ->
        send(test_pid, :search_started)
        Process.sleep(200)
        {:ok, []}
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/new")

      view |> element("button[phx-value-source='clip']") |> render_click()

      view
      |> form("#clip-search-form", %{"query" => "one more time"})
      |> render_change()

      assert_receive :search_started, 1000

      html = render_click(view, "select_clip_video", %{"video_id" => "yt_abc123"})

      refute has_element?(view, "[phx-click='prepare_session']")
      assert html =~ "Searching videos"
      refute has_element?(view, "#selected-clip-video")
    end
  end
end
