defmodule PremiereEcouteWeb.Sessions.ClipOverlayLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Hammox
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession

  setup :verify_on_exit!

  setup do
    user =
      user_fixture(%{
        role: :streamer,
        twitch: %{user_id: "1234"},
        spotify: %{user_id: "spotify_user_123", username: "spotifyuser"}
      })

    {:ok, user: user}
  end

  describe "mount/3 without an active clip session" do
    test "renders an idle overlay", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/overlay/#{user.username}/clip")

      refute has_element?(view, "[phx-hook='YoutubePlayer']")
    end
  end

  describe "mount/3 with a prepared (not yet started) clip session" do
    test "renders the clip's thumbnail instead of the player", %{conn: conn, user: user} do
      single = single_fixture()

      expect(YoutubeApi.Mock, :get_video, fn "yt_abc123" ->
        {:ok,
         %{
           id: "yt_abc123",
           title: "Sample Track (Official Video)",
           channel_title: "Sample Artist",
           duration: "PT3M30S",
           thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
         }}
      end)

      expect(SpotifyApi.Mock, :search_singles, fn _query -> {:ok, [single]} end)

      {:ok, _, _} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :clip,
          user_id: user.id,
          youtube_video_id: "yt_abc123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.username}/clip")

      refute has_element?(view, "[phx-hook='YoutubePlayer']")
      assert html =~ "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
    end
  end

  describe "an overlay already open when a clip session is prepared" do
    test "shows the thumbnail without needing a reload", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/overlay/#{user.username}/clip")

      refute has_element?(view, "img")

      single = single_fixture()

      expect(YoutubeApi.Mock, :get_video, fn "yt_abc123" ->
        {:ok,
         %{
           id: "yt_abc123",
           title: "Sample Track (Official Video)",
           channel_title: "Sample Artist",
           duration: "PT3M30S",
           thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
         }}
      end)

      expect(SpotifyApi.Mock, :search_singles, fn _query -> {:ok, [single]} end)

      {:ok, _, _} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :clip,
          user_id: user.id,
          youtube_video_id: "yt_abc123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      html = render(view)

      assert html =~ "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
    end
  end

  describe "clip commands broadcast from the dashboard" do
    test "pushes a clip_command client event when a command is broadcast", %{conn: conn, user: user} do
      single = single_fixture()

      expect(YoutubeApi.Mock, :get_video, fn "yt_abc123" ->
        {:ok,
         %{
           id: "yt_abc123",
           title: "Sample Track (Official Video)",
           channel_title: "Sample Artist",
           duration: "PT3M30S",
           thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
         }}
      end)

      expect(SpotifyApi.Mock, :search_singles, fn _query -> {:ok, [single]} end)
      stub(TwitchApi.Mock, :resubscribe, fn _scope, _event -> {:ok, %{}} end)
      stub(TwitchApi.Mock, :send_chat_message, fn _scope, _message -> :ok end)

      {:ok, _, [prepared]} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :clip,
          user_id: user.id,
          youtube_video_id: "yt_abc123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      scope = user_scope_fixture(user)

      {:ok, session, _} =
        PremiereEcoute.apply(%StartListeningSession{source: :clip, session_id: prepared.session_id, scope: scope})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/overlay/#{user.username}/clip")

      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:clip_command, %{command: "pause"}})

      assert_push_event(view, "clip_command", %{command: "pause"})
    end

    test "broadcasts clip_progress client events for the dashboard to pick up", %{conn: conn, user: user} do
      single = single_fixture()

      expect(YoutubeApi.Mock, :get_video, fn "yt_abc123" ->
        {:ok,
         %{
           id: "yt_abc123",
           title: "Sample Track (Official Video)",
           channel_title: "Sample Artist",
           duration: "PT3M30S",
           thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
         }}
      end)

      expect(SpotifyApi.Mock, :search_singles, fn _query -> {:ok, [single]} end)
      stub(TwitchApi.Mock, :resubscribe, fn _scope, _event -> {:ok, %{}} end)
      stub(TwitchApi.Mock, :send_chat_message, fn _scope, _message -> :ok end)

      {:ok, _, [prepared]} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :clip,
          user_id: user.id,
          youtube_video_id: "yt_abc123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      scope = user_scope_fixture(user)

      {:ok, session, _} =
        PremiereEcoute.apply(%StartListeningSession{source: :clip, session_id: prepared.session_id, scope: scope})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/overlay/#{user.username}/clip")

      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      render_hook(view, "clip_progress", %{"current_time" => 12.5, "duration" => 200.0, "playing" => true})

      assert_receive {:clip_progress, %{current_time: 12.5, duration: 200.0, playing: true}}
    end
  end

  describe "mount/3 with an active clip session" do
    test "renders the YouTube player with the session's video id", %{conn: conn, user: user} do
      single = single_fixture()

      expect(YoutubeApi.Mock, :get_video, fn "yt_abc123" ->
        {:ok,
         %{
           id: "yt_abc123",
           title: "Sample Track (Official Video)",
           channel_title: "Sample Artist",
           duration: "PT3M30S",
           thumbnail_url: "https://i.ytimg.com/vi/yt_abc123/maxresdefault.jpg"
         }}
      end)

      expect(SpotifyApi.Mock, :search_singles, fn _query -> {:ok, [single]} end)
      stub(TwitchApi.Mock, :resubscribe, fn _scope, _event -> {:ok, %{}} end)
      stub(TwitchApi.Mock, :send_chat_message, fn _scope, _message -> :ok end)

      {:ok, _, [prepared]} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :clip,
          user_id: user.id,
          youtube_video_id: "yt_abc123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      scope = user_scope_fixture(user)
      {:ok, _, _} = PremiereEcoute.apply(%StartListeningSession{source: :clip, session_id: prepared.session_id, scope: scope})

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.username}/clip")

      assert has_element?(view, "[phx-hook='YoutubePlayer']")
      assert html =~ Map.get(ListeningSession.get(prepared.session_id).single.provider_ids, :youtube)
    end
  end
end
