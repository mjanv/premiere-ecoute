defmodule PremiereEcoute.Festivals do
  @moduledoc false

  alias PremiereEcoute.Festivals.Services

  defdelegate analyze_poster(scope, image_path), to: Services.PosterAnalyzer
  defdelegate create_festival_playlist(scope, festival, tracks), to: Services.TrackSearch
  defdelegate find_tracks(scope, festival), to: Services.TrackSearch
end
