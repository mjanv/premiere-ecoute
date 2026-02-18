defmodule PremiereEcoute.Radio.EventHandler do
  @moduledoc """
  GenServer that reacts to Twitch stream lifecycle events to control radio track polling.

  Subscribes to "twitch:events" PubSub topic and starts/stops Spotify playback polling
  based on stream.online and stream.offline events.
  """

  use GenServer

  require Logger

  alias PremiereEcoute.Accounts
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
  def handle_info({:stream_event, %StreamStarted{broadcaster_id: broadcaster_id}}, state) do
    case Accounts.get_user_by_twitch_id(broadcaster_id) do
      %{profile: %{radio_settings: %{enabled: true}}} = user ->
        Logger.info("Radio: starting playback polling for user #{user.id}")
        TrackSpotifyPlayback.now(%{user_id: user.id})

      _ ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:stream_event, %StreamEnded{broadcaster_id: broadcaster_id}}, state) do
    case Accounts.get_user_by_twitch_id(broadcaster_id) do
      %{id: user_id} ->
        Logger.info("Radio: stopping playback polling for user #{user_id}")

        TrackSpotifyPlayback.cancel_all(user_id)

      _ ->
        :ok
    end

    {:noreply, state}
  end
end
