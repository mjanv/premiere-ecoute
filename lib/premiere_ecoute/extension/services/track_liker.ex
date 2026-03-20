defmodule PremiereEcoute.Extension.Services.TrackLiker do
  @moduledoc """
  Service for liking tracks to user playlists.

  Playlist rules have been removed. This service always returns
  `{:error, :no_playlist_rule}` for like requests.
  """

  @doc false
  @spec like_track(String.t(), String.t()) :: {:error, :no_playlist_rule}
  def like_track(_user_id, _spotify_track_id), do: {:error, :no_playlist_rule}
end
