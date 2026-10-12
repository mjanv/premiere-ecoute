defmodule PremiereEcoute.Apis.Players.SpotifyPlayer.Mode do
  @moduledoc """
  Behaviour of a `PremiereEcoute.Apis.Players.SpotifyPlayer` mode.

  The player runs in exactly one mode at a time: `Api` polls the Spotify Web API, `Local` follows the desktop player connected by the streamer. A mode owns its own keys in the player data and returns what it observed; the core diffs the observed `PlaybackState`, publishes the events and handles mode switching.
  """

  alias PremiereEcoute.Apis.Players.PlaybackState

  @doc """
  Handles a message received by the player while in this mode.

  Returns `{:observe, playback_state, data}` when a new playback state was observed, `{:noreply, data}` when there is nothing to report, `{:switch, :api, data}` when the mode cannot continue, or `{:stop, reason, data}`.
  """
  @callback handle_info(message :: term(), data :: map()) ::
              {:observe, PlaybackState.t(), map()} | {:noreply, map()} | {:switch, :api, map()} | {:stop, term(), map()}
end
