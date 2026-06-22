defmodule PremiereEcoute.Extension.TrackReader do
  @moduledoc """
  Read model for fetching track information.

  This module handles reading track data from Spotify sessions for
  broadcaster users in the extension context. Playback state is cached
  per broadcaster to reduce Spotify API load when multiple viewers poll
  concurrently.
  """

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState

  @doc """
  Gets the current playing track for a broadcaster.

  Returns the currently playing track from the broadcaster's Spotify session
  if they have an active session and a track is playing.

  ## Examples

      iex> get_current_track("broadcaster123")
      {:ok, %{name: "Song Name", artist: "Artist Name", ...}}

      iex> get_current_track("nonexistent")
      {:error, :no_user}
  """
  @spec get_current_track(String.t()) :: {:ok, map()} | {:error, atom()}
  def get_current_track(broadcaster_id) do
    with {:ok, user} <- get_broadcaster_user(broadcaster_id),
         true <- user.spotify != nil or {:error, :no_spotify},
         {:ok, state} <- Apis.cache(:spotify).get_playback_state(Scope.for_user(user), PlaybackState.default()),
         {:ok, track_data} <- extract_track_from_playback(state) do
      {:ok, track_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp get_broadcaster_user(broadcaster_id) do
    case Accounts.get_user_by_twitch_id(broadcaster_id) do
      nil -> {:error, :no_user}
      user -> {:ok, user}
    end
  end

  defp extract_track_from_playback(%PlaybackState{is_playing: false}), do: {:error, :no_track}
  defp extract_track_from_playback(%PlaybackState{item: nil}), do: {:error, :no_track}

  defp extract_track_from_playback(%PlaybackState{item: %{uri: "spotify:track:" <> spotify_id} = item, is_playing: true}) do
    track_data = %{
      id: nil,
      name: item.name,
      artist: Enum.map_join(item.artists, ", ", & &1.name),
      duration_ms: item.duration_ms,
      spotify_id: spotify_id
    }

    {:ok, track_data}
  end

  defp extract_track_from_playback(_), do: {:error, :no_track}
end
