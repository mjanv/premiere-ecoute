defmodule PremiereEcoute.Apis.SpotifyApi do
  @moduledoc "Spotify API"

  defmodule Behavior do
    @moduledoc "Defines the Spotify interface"

    alias PremiereEcoute.Session.Discography.Album

    @callback search_albums(query :: String.t()) :: {:ok, [Album.t()]} | {:error, term()}
    @callback get_album(album_id :: String.t()) :: {:ok, Album.t()} | {:error, term()}
  end

  @behaviour __MODULE__.Behavior
  @app :premiere_ecoute
  @web "https://api.spotify.com/v1"
  @accounts "https://accounts.spotify.com/api"

  @spec api(:web | :accounts) :: Req.Request.t()
  def api(:web) do
    case client_credentials() do
      {:ok, token} ->
        Req.new(base_url: @web, headers: [{"Authorization", "Bearer #{token}"}])

      {:error, _} ->
        Req.new(base_url: @web)
    end
  end

  def api(:accounts) do
    with id when not is_nil(id) <- Application.get_env(@app, :spotify_client_id),
         secret when not is_nil(secret) <- Application.get_env(@app, :spotify_client_secret) do
      Req.new(
        base_url: @accounts,
        headers: [
          {"Authorization", "Basic #{Base.encode64("#{id}:#{secret}")}"},
          {"Content-Type", "application/x-www-form-urlencoded"}
        ]
      )
    else
      _ -> Req.new(base_url: @accounts)
    end
  end

  defdelegate client_credentials, to: __MODULE__.Accounts
  defdelegate authorization_url, to: __MODULE__.Accounts
  defdelegate authorization_code(code, state), to: __MODULE__.Accounts
  @impl true
  defdelegate search_albums(query), to: __MODULE__.Search
  @impl true
  defdelegate get_album(album_id), to: __MODULE__.Albums
end
