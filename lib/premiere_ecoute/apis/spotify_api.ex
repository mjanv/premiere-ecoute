defmodule PremiereEcoute.Apis.SpotifyApi do
  @moduledoc """
  # Spotify API Client

  Central client for Spotify Web API integration providing music search, album retrieval, player control, and authentication functionality. This module acts as the main interface for all Spotify-related operations, delegating to specialized submodules for specific API domains while handling common concerns like authentication, request configuration, and telemetry.

  ## Accounts

  Handles OAuth2 authorization flow with Spotify, including generating authorization URLs, exchanging authorization codes for access tokens, and refreshing expired tokens. Supports both client credentials flow for public data and authorization code flow for user-specific operations.

  ## Albums

  Provides access to Spotify's album catalog, enabling retrieval of detailed album information including tracks, metadata, and artwork. Album data is parsed into structured domain objects for use throughout the application.

  ## Player

  Controls Spotify playback for authenticated users with premium accounts. Supports play/pause operations, track navigation, queue management, and playback state monitoring. Integrates with user's active Spotify devices for seamless music control.

  ## Search

  Enables searching Spotify's music catalog for albums, tracks, and artists. Returns structured results that can be used for music discovery and selection within listening sessions.
  """

  require Logger

  alias PremiereEcoute.Core.Cache
  alias PremiereEcoute.Telemetry
  alias PremiereEcoute.Telemetry.Apis.SpotifyApiMetrics

  defmodule Behavior do
    @moduledoc """
    Spotify API Behavior
    """

    alias PremiereEcoute.Accounts.Scope
    alias PremiereEcoute.Sessions.Discography.Album
    alias PremiereEcoute.Sessions.Discography.Album.Track
    alias PremiereEcoute.Sessions.Discography.Playlist

    # Albums
    @callback get_album(album_id :: String.t()) :: {:ok, Album.t()} | {:error, term()}

    # Player
    @callback get_playback_state(scope :: Scope.t()) :: {:ok, map()} | {:error, term()}
    @callback start_playback(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback pause_playback(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback next_track(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback previous_track(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback start_resume_playback(scope :: Scope.t(), item :: Album.t() | Track.t()) :: {:ok, String.t()} | {:error, term()}
    @callback add_item_to_playback_queue(scope :: Scope.t(), item :: Album.t() | Track.t()) ::
                {:ok, String.t() | [String.t()]} | {:error, term()}

    # Playlists
    @callback get_playlist(playlist_id :: String.t()) :: {:ok, Playlist.t()} | {:error, term()}
    @callback get_user_playlists(scope :: Scope.t()) :: {:ok, [Playlist.t()]} | {:error, term()}
    @callback add_items_to_playlist(scope :: Scope.t(), id :: String.t(), tracks :: [Track.t()]) ::
                {:ok, map()} | {:error, term()}
    @callback remove_playlist_items(scope :: Scope.t(), id :: String.t(), tracks :: [Track.t()], snapshot :: map()) ::
                {:ok, map()} | {:error, term()}

    # Search
    @callback search_albums(query :: String.t()) :: {:ok, [Album.t()]} | {:error, term()}
  end

  @behaviour __MODULE__.Behavior
  @app :premiere_ecoute
  @web "https://api.spotify.com/v1"
  @accounts "https://accounts.spotify.com/api"

  def impl, do: Application.get_env(@app, :spotify_api, __MODULE__)

  @spec api(:web | :accounts, String.t() | nil) :: Req.Request.t()
  def api(type, token \\ nil)

  def api(:web, token) do
    token =
      with {:ok, nil} <- {:ok, token},
           {:ok, nil} <- Cache.get(:tokens, :spotify_access_token),
           {:ok, token} <- PremiereEcoute.Apis.SpotifyApi.Accounts.client_credentials() do
        token
      else
        {:ok, token} ->
          token

        {:error, reason} ->
          Logger.error("Cannot retrieve Spotify app access token due to #{inspect(reason)}")
          ""
      end

    [
      base_url: @web,
      headers: [{"Authorization", "Bearer #{token}"}]
    ]
    |> Keyword.merge(Application.get_env(@app, :spotify_req_options, []))
    |> Req.new()
    |> Telemetry.ReqPipeline.attach(&SpotifyApiMetrics.api_called/1)
  end

  def api(:accounts, _) do
    with id when not is_nil(id) <- Application.get_env(@app, :spotify_client_id),
         secret when not is_nil(secret) <- Application.get_env(@app, :spotify_client_secret) do
      Req.new(
        [
          base_url: @accounts,
          headers: [
            {"Authorization", "Basic #{Base.encode64("#{id}:#{secret}")}"},
            {"Content-Type", "application/x-www-form-urlencoded"}
          ]
        ]
        |> Keyword.merge(Application.get_env(@app, :spotify_req_options, []))
      )
    else
      _ -> Req.new(base_url: @accounts)
    end
  end

  # Accounts
  defdelegate client_credentials, to: __MODULE__.Accounts
  defdelegate authorization_url, to: __MODULE__.Accounts
  defdelegate authorization_url(state), to: __MODULE__.Accounts
  defdelegate authorization_code(code, state), to: __MODULE__.Accounts
  defdelegate renew_token(refresh_token), to: __MODULE__.Accounts

  # Albums
  defdelegate get_album(album_id), to: __MODULE__.Albums

  # Player
  defdelegate get_playback_state(scope), to: __MODULE__.Player
  defdelegate start_playback(scope), to: __MODULE__.Player
  defdelegate pause_playback(scope), to: __MODULE__.Player
  defdelegate next_track(scope), to: __MODULE__.Player
  defdelegate previous_track(scope), to: __MODULE__.Player
  defdelegate start_resume_playback(scope, album), to: __MODULE__.Player
  defdelegate add_item_to_playback_queue(scope, item), to: __MODULE__.Player

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
  defdelegate get_user_playlists(scope), to: __MODULE__.Playlists
  defdelegate add_items_to_playlist(scope, id, tracks), to: __MODULE__.Playlists
  defdelegate remove_playlist_items(scope, id, tracks, snapshot), to: __MODULE__.Playlists

  # Search
  defdelegate search_albums(query), to: __MODULE__.Search
end
