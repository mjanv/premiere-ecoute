defmodule PremiereEcouteWeb.Sessions.SessionLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    start_supervised(PremiereEcoute.Apis.PlayerSupervisor)
    :ok
  end

  describe "auto-start for track sessions" do
    test "automatically starts session on mount when source is :track and status is :preparing", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "1234"}, spotify: %{}})
      single = single_fixture()
      {:ok, persisted_single} = Single.create_if_not_exists(single)

      {:ok, session} =
        ListeningSession.create(%{
          user_id: user.id,
          source: :track,
          single_id: persisted_single.id,
          status: :preparing,
          visibility: :protected,
          options: %{"votes" => 0, "scores" => true, "next_track" => 0},
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state ->
        {:ok, %{"item" => %{"id" => persisted_single.track_id}, "is_playing" => true}}
      end)

      expect(SpotifyApi.Mock, :devices, fn _scope -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :resubscribe, fn %Scope{}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, _message -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, _promo -> :ok end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/#{session.id}")

      # Wait for auto_start message to be processed
      :sys.get_state(view.pid)

      session = ListeningSession.get(session.id)
      assert session.status == :active
    end
  end
end
