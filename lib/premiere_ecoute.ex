defmodule PremiereEcoute do
  @moduledoc false

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Core

  defdelegate apply(command), to: Core

  defdelegate search_albums(query), to: SpotifyApi
  defdelegate get_album(album_id), to: SpotifyApi
end
