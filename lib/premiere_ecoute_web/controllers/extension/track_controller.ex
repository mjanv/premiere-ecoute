defmodule PremiereEcouteWeb.Extension.TrackController do
  @moduledoc """
  Controller for Twitch extension track-related endpoints.

  Handles requests from the Twitch extension including:
  - Fetching current track from active listening sessions
  - Liking tracks to user Spotify playlists
  - Managing extension user preferences
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Extension

  require Logger

  plug PremiereEcouteWeb.Plugs.TwitchExtensionAuth

  def current_track(conn, %{"broadcaster_id" => broadcaster_id}) do
    case Extension.get_current_track(broadcaster_id) do
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

  def like_track(conn, %{"user_id" => user_id, "spotify_track_id" => spotify_track_id}) do
    # AIDEV-NOTE: Uses configured playlist rules only - no fallback behavior
    case Extension.like_track(user_id, spotify_track_id) do
      {:ok, playlist_name} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          message: "Track liked successfully",
          playlist_name: playlist_name,
          spotify_track_id: spotify_track_id
        })

      {:error, :no_user} ->
        Logger.info("No user found for user ID: #{user_id}")

        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found or not connected to Spotify"})

      {:error, :no_spotify} ->
        Logger.info("User #{user_id} has no Spotify connection")

        conn
        |> put_status(:not_found)
        |> json(%{error: "User not connected to Spotify"})

      {:error, :no_playlist_rule} ->
        Logger.info("No playlist rule configured for user #{user_id}")

        conn
        |> put_status(:not_found)
        |> json(%{
          error: "No playlist rule configured. Please configure a playlist rule in the application settings."
        })

      {:error, reason} ->
        Logger.error("Failed to like track for user #{user_id}: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to like track"})
    end
  end

  def like_track(conn, params) do
    Logger.warning("Invalid like track request: #{inspect(params)}")

    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: user_id and spotify_track_id"})
  end
end
