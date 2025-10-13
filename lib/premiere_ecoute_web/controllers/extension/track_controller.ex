defmodule PremiereEcouteWeb.Extension.TrackController do
  @moduledoc """
  Controller for Twitch extension track-related endpoints.

  Handles requests from the Twitch extension including:
  - Fetching current track from active listening sessions
  - Saving tracks to user Spotify playlists
  - Managing extension user preferences
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis

  require Logger

  # plug PremiereEcouteWeb.Plugs.TwitchExtensionAuth  # Disabled for testing

  def current_track(conn, %{"broadcaster_id" => broadcaster_id}) do
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

  def save_track(conn, %{"user_id" => user_id, "spotify_track_id" => spotify_track_id}) do
    case save_track_to_flonflon_playlist(user_id, spotify_track_id) do
      {:ok, playlist_name} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          message: "Track saved successfully",
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

      {:error, :no_flonflon_playlist} ->
        Logger.info("No Flonflon playlist found for user #{user_id}")

        conn
        |> put_status(:not_found)
        |> json(%{error: "No Flonflon playlist found. Please create a playlist with 'Flonflon' in the name."})

      {:error, reason} ->
        Logger.error("Failed to save track for user #{user_id}: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to save track"})
    end
  end

  def save_track(conn, params) do
    Logger.warning("Invalid save track request: #{inspect(params)}")

    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: user_id and spotify_track_id"})
  end

  # Private functions

  defp save_track_to_flonflon_playlist(user_id, spotify_track_id) do
    with {:ok, user} <- get_saver_user(user_id),
         {:ok, spotify_scope} <- get_spotify_scope(user),
         {:ok, flonflon_playlist} <- find_flonflon_playlist(spotify_scope),
         {:ok, _result} <- add_track_to_playlist(spotify_scope, flonflon_playlist, spotify_track_id) do
      {:ok, flonflon_playlist.title}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_saver_user(user_id) do
    case Accounts.get_user_by_twitch_id(user_id) do
      nil -> {:error, :no_user}
      user -> {:ok, user}
    end
  end

  defp find_flonflon_playlist(spotify_scope) do
    case get_all_user_playlists(spotify_scope) do
      {:ok, playlists} ->
        flonflon_playlist =
          Enum.find(playlists, fn playlist ->
            String.contains?(String.downcase(playlist.title), "flonflon")
          end)

        case flonflon_playlist do
          nil -> {:error, :no_flonflon_playlist}
          playlist -> {:ok, playlist}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_all_user_playlists(spotify_scope) do
    Apis.spotify().get_library_playlists(spotify_scope)
  end

  defp add_track_to_playlist(spotify_scope, playlist, spotify_track_id) do
    Apis.spotify().add_items_to_playlist(spotify_scope, playlist.playlist_id, [%{track_id: spotify_track_id}])
  end

  defp get_current_spotify_track(broadcaster_id) do
    with {:ok, user} <- get_broadcaster_user(broadcaster_id),
         {:ok, spotify_scope} <- get_spotify_scope(user),
         {:ok, playback_state} <- Apis.spotify().get_playback_state(spotify_scope, %{}),
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
end
