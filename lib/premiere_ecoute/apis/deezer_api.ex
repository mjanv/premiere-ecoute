defmodule PremiereEcoute.Apis.DeezerApi do
  @moduledoc false

  use PremiereEcouteCore.Api, api: :deezer

  defmodule Behaviour do
    @moduledoc "Deezer API Behaviour"

    alias PremiereEcoute.Discography.Playlist

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

  @spec client_credentials() :: {:ok, %{String.t() => String.t() | integer()}}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
end
