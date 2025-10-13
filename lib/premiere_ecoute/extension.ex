defmodule PremiereEcoute.Extension do
  @moduledoc """
  Extension context for Twitch extension functionality.

  This module handles the business logic for extension operations including:
  - Fetching current track from active listening sessions
  - Saving tracks to user Spotify playlists
  - Managing extension user preferences
  """

  alias PremiereEcoute.Extension.Services.TrackSaver
  alias PremiereEcoute.Extension.TrackReader

  # AIDEV-NOTE: defdelegate pattern for clean separation of read vs write operations
  defdelegate get_current_track(broadcaster_id), to: TrackReader
  defdelegate save_track(user_id, spotify_track_id, playlist_search_term), to: TrackSaver
end
