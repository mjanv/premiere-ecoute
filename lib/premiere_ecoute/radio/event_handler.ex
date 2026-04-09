defmodule PremiereEcoute.Radio.EventHandler do
  @moduledoc """
  GenServer that reacts to Twitch stream lifecycle events to control radio track polling.

  Subscribes to "twitch:events" PubSub topic and starts/stops Spotify playback polling based on stream.online and stream.offline events.
  """

  use GenServer

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Events.Twitch.StreamEnded
  alias PremiereEcoute.Events.Twitch.StreamStarted
  alias PremiereEcoute.Radio.Workers.TrackSpotifyPlayback

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "twitch:events")
    {:ok, %{}}
  end

  @impl true
  def handle_info(%StreamStarted{broadcaster_id: broadcaster_id}, state) do
    case Accounts.get_user_by_twitch_id(broadcaster_id) do
      nil ->
        :ok

      user ->
        if Accounts.profile(user, [:radio_settings, :enabled], false) do
          Logger.info("[PremiereEcoute.Radio] starting radio for user #{user.username}")
          TrackSpotifyPlayback.now(%{user_id: user.id})
        end

        if Accounts.profile(user, [:chat_settings, :save_wantlist], false) do
          Logger.info("[PremiereEcoute.Radio] subscribing chat for user #{user.username}")
          Apis.twitch().subscribe(Scope.for_user(user), "channel.chat.message")
        end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(%StreamEnded{broadcaster_id: broadcaster_id}, state) do
    case Accounts.get_user_by_twitch_id(broadcaster_id) do
      nil ->
        :ok

      user ->
        if Accounts.profile(user, [:radio_settings, :enabled], false) do
          Logger.info("[PremiereEcoute.Radio] stopping radio for user #{user.username}")
          TrackSpotifyPlayback.cancel_all(user.id)
        end

        if Accounts.profile(user, [:chat_settings, :save_wantlist], false) do
          Logger.info("[PremiereEcoute.Radio] unsubscribing chat for user #{user.username}")
          Apis.twitch().unsubscribe(Scope.for_user(user), "channel.chat.message")
        end
    end

    {:noreply, state}
  end
end
