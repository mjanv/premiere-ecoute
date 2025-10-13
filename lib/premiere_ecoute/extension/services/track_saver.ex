defmodule PremiereEcoute.Extension.Services.TrackSaver do
  @moduledoc """
  Service for saving tracks to user playlists.

  This service handles the business logic for saving Spotify tracks
  to a user's designated playlist by searching for playlists containing
  a specified search term.
  """

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis

  require Logger

  @doc """
  Saves a track to a user's playlist matching the given search term.

  Finds the user's playlist containing the search term in the name and adds the specified
  Spotify track to it.

  ## Examples

      iex> save_track("user123", "spotify_track_id", "flonflon")
      {:ok, "My Flonflon Hits"}
      
      iex> save_track("nonexistent", "track_id", "flonflon")
      {:error, :no_user}
  """
  def save_track(user_id, spotify_track_id, playlist_search_term) do
    with {:ok, user} <- get_user(user_id),
         {:ok, spotify_scope} <- get_spotify_scope(user),
         {:ok, target_playlist} <- find_playlist_by_search_term(spotify_scope, playlist_search_term),
         {:ok, _result} <- add_track_to_playlist(spotify_scope, target_playlist, spotify_track_id) do
      {:ok, target_playlist.title}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp get_user(user_id) do
    case Accounts.get_user_by_twitch_id(user_id) do
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

  defp find_playlist_by_search_term(spotify_scope, search_term) do
    case get_all_user_playlists(spotify_scope) do
      {:ok, playlists} ->
        target_playlist =
          Enum.find(playlists, fn playlist ->
            String.contains?(String.downcase(playlist.title), String.downcase(search_term))
          end)

        case target_playlist do
          nil -> {:error, :no_matching_playlist}
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
end
