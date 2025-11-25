defmodule PremiereEcoute.Apis.TidalApi.Playlists do
  @moduledoc """
  Tidal playlists API.

  Fetches playlist data from Tidal API and parses into Playlist aggregates.
  """

  alias PremiereEcoute.Apis.TidalApi
  alias PremiereEcoute.Discography.Playlist

  def get_playlist(playlist_id) when is_binary(playlist_id) do
    {:ok, %{"access_token" => token}} = TidalApi.client_credentials()

    TidalApi.api(token)
    |> TidalApi.get(url: "/playlists/#{playlist_id}", params: %{countryCode: "FR", include: "coverArt,items"})
    |> TidalApi.handle(200, &parse_playlist/1)
  end

  defp parse_playlist(%{"data" => data}) do
    %Playlist{
      provider: :tidal,
      playlist_id: data["id"],
      title: data["attributes"]["name"],
      tracks: Enum.map(data["relationships"]["items"]["data"], &parse_track/1)
    }
  end

  defp parse_track(data) do
    data["id"]
  end
end
