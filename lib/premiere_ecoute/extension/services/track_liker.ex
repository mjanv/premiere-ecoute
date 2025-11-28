defmodule PremiereEcoute.Extension.Services.TrackLiker do
  @moduledoc """
  Service for liking tracks to user playlists.

  This service handles the business logic for liking Spotify tracks
  to a user's designated playlist using configured playlist rules.
  """

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Events.TrackLiked
  alias PremiereEcoute.Playlists

  require Logger

  @doc """
  Likes a track to a user's designated playlist.

  Uses playlist rules to determine the target playlist. If no rule is
  configured, the track will not be liked.

  ## Examples

      iex> like_track("user123", "spotify_track_id")
      {:ok, "My Configured Playlist"}

      iex> like_track("user_no_rule", "track_id")
      {:error, :no_playlist_rule}

      iex> like_track("nonexistent", "track_id")
      {:error, :no_user}
  """
  @spec like_track(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def like_track(user_id, spotify_track_id) do
    with {:ok, user} <- get_user(user_id),
         {:ok, spotify_scope} <- get_spotify_scope(user),
         {:ok, target_playlist} <- find_target_playlist(user),
         {:ok, _result} <- add_track_to_playlist(spotify_scope, target_playlist, spotify_track_id) do
      {:ok, target_playlist.title}
      |> Store.ok("like", fn _title ->
        %TrackLiked{
          id: user_id,
          provider: :spotify,
          user_id: user.id,
          track_id: spotify_track_id
        }
      end)
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

  defp find_target_playlist(user) do
    case Playlists.get_save_tracks_playlist(user) do
      %PremiereEcoute.Discography.LibraryPlaylist{} = playlist ->
        {:ok, playlist}

      nil ->
        Logger.info("No playlist rule configured for user #{user.id}, track will not be liked")
        {:error, :no_playlist_rule}
    end
  end

  defp add_track_to_playlist(spotify_scope, playlist, spotify_track_id) do
    track = %PremiereEcoute.Discography.Album.Track{
      provider: :spotify,
      track_id: spotify_track_id,
      # We don't have track metadata here, just the ID
      name: "Unknown",
      track_number: 1,
      duration_ms: 0
    }

    Apis.spotify().add_items_to_playlist(spotify_scope, playlist.playlist_id, [track])
  end
end
