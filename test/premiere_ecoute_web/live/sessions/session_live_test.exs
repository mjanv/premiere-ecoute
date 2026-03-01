defmodule PremiereEcouteWeb.Sessions.SessionLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession

  setup do
    start_supervised(PremiereEcoute.Apis.PlayerSupervisor)
    :ok
  end

  describe "auto-start for track sessions" do
    test "automatically starts session after prepare when track is already playing on Spotify", _context do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "1234"}, spotify: %{}})

      stub(SpotifyApi.Mock, :get_single, fn track_id ->
        {:ok, single_fixture(%{track_id: track_id})}
      end)

      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state ->
        {:ok, %{"item" => %{"id" => "track123"}, "is_playing" => true}}
      end)

      expect(SpotifyApi.Mock, :devices, fn _scope -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :resubscribe, fn %Scope{}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, _message -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, _promo -> :ok end)

      {:ok, session, _} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :track,
          user_id: user.id,
          track_id: "track123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      assert ListeningSession.get(session.id).status == :active
    end

    test "does not auto-start session after prepare when track is not playing on Spotify", _context do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "1234"}, spotify: %{}})

      stub(SpotifyApi.Mock, :get_single, fn track_id ->
        {:ok, single_fixture(%{track_id: track_id})}
      end)

      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state ->
        {:ok, %{"is_playing" => false}}
      end)

      {:ok, session, _} =
        PremiereEcoute.apply(%PrepareListeningSession{
          source: :track,
          user_id: user.id,
          track_id: "track123",
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      assert session.status == :preparing
    end
  end
end
