defmodule PremiereEcoute.Festivals do
  @moduledoc """
  Festivals context.

  Analyzes festival posters to extract lineups, searches for artist tracks on Spotify, and creates festival playlists.
  """

  alias PremiereEcoute.Festivals.Services

  defdelegate analyze_poster(scope, image_path), to: Services.PosterAnalyzer
  defdelegate create_festival_playlist(scope, festival, tracks), to: Services.TrackSearch
  defdelegate find_tracks(scope, festival), to: Services.TrackSearch
end
