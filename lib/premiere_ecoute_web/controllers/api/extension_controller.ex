defmodule PremiereEcouteWeb.Api.ExtensionController do
  @moduledoc """
  API controller for Twitch extension endpoints.

  Handles requests from the Twitch extension including:
  - Fetching current track from active listening sessions
  - Saving tracks to user Spotify playlists
  - Managing extension user preferences
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.SpotifyApi.Player
  alias PremiereEcoute.Sessions
  alias PremiereEcouteCore.Cache

  require Logger

  # plug PremiereEcouteWeb.Plugs.TwitchExtensionAuth  # Disabled for testing

  @doc """
  GET /api/extension/current-track/:broadcaster_id

  Returns the current playing track from the broadcaster's Spotify account.
  """
  def current_track(conn, %{"broadcaster_id" => broadcaster_id}) do
    Logger.info("Extension current track request for broadcaster: #{broadcaster_id}")

    case get_current_spotify_track(broadcaster_id) do
      {:ok, track_data} ->
        conn
        |> put_status(:ok)
        |> json(%{
          track: track_data,
          broadcaster_id: broadcaster_id
        })

      {:error, :no_user} ->
        Logger.info("No user found for broadcaster ID: #{broadcaster_id}")

        conn
        |> put_status(:not_found)
        |> json(%{error: "Broadcaster not found or not connected to Spotify"})

      {:error, :no_spotify} ->
        Logger.info("Broadcaster #{broadcaster_id} has no Spotify connection")

        conn
        |> put_status(:not_found)
        |> json(%{error: "Broadcaster not connected to Spotify"})

      {:error, :no_track} ->
        Logger.info("No track currently playing for broadcaster #{broadcaster_id}")

        conn
        |> put_status(:not_found)
        |> json(%{error: "No track currently playing"})

      {:error, reason} ->
        Logger.error("Failed to get current track for broadcaster #{broadcaster_id}: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch current track"})
    end
  end

  @doc """
  POST /api/extension/save-track

  Logs track save requests from the extension.
  For now, just logs the request without implementing save functionality.
  """
  def save_track(conn, params) do
    # Log the save track request
    Logger.info("Extension save track request #{inspect(params)}")

    # For testing, just return success without auth check
    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      message: "Track save request logged (not implemented yet)",
      user_id: "mock_user_id",
      channel_id: "mock_channel_id"
    })
  end

  # Private functions

  defp get_current_spotify_track(broadcaster_id) do
    with {:ok, user} <- get_broadcaster_user(broadcaster_id),
         {:ok, spotify_scope} <- get_spotify_scope(user),
         {:ok, playback_state} <- Player.get_playback_state(spotify_scope, %{}),
         {:ok, track_data} <- extract_track_from_playback(playback_state) do
      {:ok, track_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

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

  defp get_active_session_for_broadcaster(broadcaster_id) do
    # Check cache first for performance
    case Cache.get(:sessions, broadcaster_id) do
      nil ->
        # Fallback to database query
        Sessions.get_active_session_by_twitch_user_id(broadcaster_id)

      cached_session ->
        # Validate cached session is still active
        if cached_session.status == :active do
          cached_session
        else
          nil
        end
    end
  end

  defp format_track_for_extension(%{current_track: nil}), do: nil

  defp format_track_for_extension(%{current_track: track, album: album}) when not is_nil(track) do
    %{
      id: track.id,
      name: track.name,
      artist: album.artist,
      album: album.name,
      track_number: track.track_number,
      duration_ms: track.duration_ms,
      spotify_id: track.spotify_id,
      preview_url: track.preview_url
    }
  end

  defp format_track_for_extension(_), do: nil
end
