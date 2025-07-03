defmodule PremiereEcoute do
  @moduledoc false

  alias PremiereEcoute.Apis.SpotifyApi

  def apply(command), do: PremiereEcouteWeb.PubSub.broadcast("command_bus", command)

  defdelegate search_albums(query), to: SpotifyApi
  defdelegate get_album(album_id), to: SpotifyApi
end
