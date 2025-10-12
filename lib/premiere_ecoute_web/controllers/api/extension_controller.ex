defmodule PremiereEcouteWeb.Api.ExtensionController do
  @moduledoc """
  API controller for Twitch extension endpoints.

  Handles requests from the Twitch extension including:
  - Fetching current track from active listening sessions
  - Saving tracks to user Spotify playlists
  - Managing extension user preferences
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Sessions
  alias PremiereEcouteCore.Cache

  require Logger

  # plug PremiereEcouteWeb.Plugs.TwitchExtensionAuth  # Disabled for testing

  @doc """
  GET /api/extension/current-track/:broadcaster_id

  Returns a static track for testing purposes.
  """
  def current_track(conn, %{"broadcaster_id" => broadcaster_id}) do
    # Return static track for testing
    track_data = %{
      id: 1,
      name: "Blinding Lights",
      artist: "The Weeknd",
      album: "After Hours",
      track_number: 3,
      duration_ms: 200_040,
      spotify_id: "0VjIjW4GlUZAMYd2vXMi3b",
      preview_url: "https://p.sndcdn.com/preview.mp3"
    }

    conn
    |> put_status(:ok)
    |> json(%{
      track: track_data,
      session_id: 123,
      broadcaster_id: broadcaster_id
    })
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
