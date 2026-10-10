defmodule PremiereEcoute.Twitch.EventHandler do
  @moduledoc """
  GenServer that reacts to Twitch stream lifecycle events.

  Subscribes to "twitch:events" PubSub topic and, on stream.online, enqueues `SpotifyProbe` for streamers with Spotify connected.
  """

  use GenServer

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Apis.Players.SpotifyProbe
  alias PremiereEcoute.Events.Twitch.StreamStarted

  @doc """
  Starts the handler that listens to Twitch stream events.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "twitch:events")
    {:ok, %{}}
  end

  @impl true
  def handle_info(%StreamStarted{broadcaster_id: broadcaster_id}, state) do
    with %{spotify: %{}} = user <- Accounts.get_user_by_twitch_id(broadcaster_id) do
      SpotifyProbe.now(%{user_id: user.id, started_at: DateTime.to_iso8601(DateTime.utc_now())})
    end

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
