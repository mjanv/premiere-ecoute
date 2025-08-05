defmodule PremiereEcoute.Apis.DeezerApi do
  @moduledoc false

  use PremiereEcoute.Core.Api, api: :deezer

  defmodule Behaviour do
    @moduledoc "Deezer API Behaviour"

    alias PremiereEcoute.Sessions.Discography.Playlist

    # Playlists
    @callback get_playlist(playlist_id :: String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  end

  @spec api :: Req.Request.t()
  def api do
    [
      base_url: url(:api),
      headers: [{"Content-Type", "application/json"}]
    ]
    |> new()
  end

  def client_credentials, do: %{}

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
end
