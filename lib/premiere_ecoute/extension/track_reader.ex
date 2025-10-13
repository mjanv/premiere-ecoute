defmodule PremiereEcoute.Extension.TrackReader do
  @moduledoc """
  Read model for fetching track information.

  This module handles reading track data from Spotify sessions for
  broadcaster users in the extension context.
  """

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis

  require Logger

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
  def get_current_track(broadcaster_id) do
    with {:ok, user} <- get_broadcaster_user(broadcaster_id),
         {:ok, spotify_scope} <- get_spotify_scope(user),
         {:ok, playback_state} <- Apis.spotify().get_playback_state(spotify_scope, %{}),
         {:ok, track_data} <- extract_track_from_playback(playback_state) do
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

  defp get_spotify_scope(%{spotify: nil}), do: {:error, :no_spotify}

  defp get_spotify_scope(%{spotify: _spotify_token} = user) do
    # Create a Scope struct with the user (which includes preloaded spotify data)
    scope = %Scope{user: user}
    {:ok, scope}
  end

  defp extract_track_from_playback(%{"is_playing" => false}), do: {:error, :no_track}
  defp extract_track_from_playback(%{"item" => nil}), do: {:error, :no_track}

  defp extract_track_from_playback(%{"item" => item, "is_playing" => true}) do
    track_data = %{
      # We don't have internal track ID
      id: nil,
      name: item["name"],
      artist: get_artist_names(item["artists"]),
      album: item["album"]["name"],
      track_number: item["track_number"],
      duration_ms: item["duration_ms"],
      spotify_id: item["id"],
      preview_url: item["preview_url"]
    }

    {:ok, track_data}
  end

  defp extract_track_from_playback(_), do: {:error, :no_track}

  defp get_artist_names(artists) when is_list(artists) do
    artists
    |> Enum.map(& &1["name"])
    |> Enum.join(", ")
  end

  defp get_artist_names(_), do: "Unknown Artist"
end
