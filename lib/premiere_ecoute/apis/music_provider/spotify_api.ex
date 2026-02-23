defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi do
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

  use PremiereEcouteCore.Api,
    api: :spotify,
    behaviours: [
      PremiereEcoute.Apis.MusicProvider.Oauth,
      PremiereEcoute.Apis.MusicProvider.Albums,
      PremiereEcoute.Apis.MusicProvider.Playlists
    ]

  alias PremiereEcoute.Accounts.Scope

  defmodule Behaviour do
    @moduledoc """
    Spotify API Behaviour
    """

    alias PremiereEcoute.Accounts.Scope
    alias PremiereEcoute.Discography.Album
    alias PremiereEcoute.Discography.Album.Track
    alias PremiereEcoute.Discography.LibraryPlaylist
    alias PremiereEcoute.Discography.Playlist

    # Artists
    @callback get_artist_top_track(artist_id :: String.t()) :: {:ok, Playlist.Track.t()} | {:error, term()}

    # Player
    @callback devices(scope :: Scope.t()) :: any()
    @callback get_playback_state(scope :: Scope.t(), state :: map()) :: {:ok, map()} | {:error, term()}
    @callback start_playback(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback pause_playback(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback next_track(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback previous_track(scope :: Scope.t()) :: {:ok, atom()} | {:error, term()}
    @callback set_repeat_mode(scope :: Scope.t(), state :: :track | :context | :off) ::
                {:ok, atom()} | {:error, term()}
    @callback toggle_playback_shuffle(scope :: Scope.t(), state :: boolean()) ::
                {:ok, atom()} | {:error, term()}
    @callback start_resume_playback(scope :: Scope.t(), item :: Album.t() | Track.t() | Playlist.t()) ::
                {:ok, String.t()} | {:error, term()}
    @callback add_item_to_playback_queue(scope :: Scope.t(), item :: Album.t() | Track.t()) ::
                {:ok, String.t() | [String.t()]} | {:error, term()}

    # Playlists
    @callback get_library_playlists(scope :: Scope.t()) :: {:ok, [LibraryPlaylist.t()]} | {:error, term()}
    @callback create_playlist(scope :: Scope.t(), library :: map()) :: {:ok, LibraryPlaylist.t()} | {:error, term()}
    @callback add_items_to_playlist(scope :: Scope.t(), id :: String.t(), tracks :: [Track.t()]) ::
                {:ok, map()} | {:error, term()}
    @callback replace_items_to_playlist(scope :: Scope.t(), id :: String.t(), tracks :: [Track.t()]) ::
                {:ok, map()} | {:error, term()}
    @callback remove_playlist_items(scope :: Scope.t(), id :: String.t(), tracks :: [Track.t()]) ::
                {:ok, map()} | {:error, term()}

    # Search
    @callback search_albums(query :: String.t()) :: {:ok, [Album.t()]} | {:error, term()}
    @callback search_artist(query :: String.t()) :: {:ok, map()} | {:error, term()}

    # Users
    @callback get_user_profile(access_token :: String.t()) :: {:ok, map()} | {:error, term()}
  end

  @doc """
  Creates a Req client for Spotify Web API with client credentials.

  Uses client credentials OAuth token for public API access.
  """
  @spec api :: Req.Request.t()
  def api do
    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{token(nil)}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Creates a Req client for Spotify Web API with user authentication.

  Accepts either a Scope struct with user access token or a raw access token string. Enables user-specific operations like playback control and playlist management.
  """
  @spec api(Scope.t() | binary()) :: Req.Request.t()
  def api(%Scope{user: %{spotify: %{access_token: access_token}}}) do
    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  def api(token) when is_binary(token) do
    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{token(token)}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Creates a Req client for Spotify Accounts API.

  Configures basic authentication with client ID and secret for OAuth token operations.
  """
  @spec accounts :: Req.Request.t()
  def accounts do
    id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)

    [
      base_url: url(:accounts),
      headers: [
        {"Authorization", "Basic #{Base.encode64("#{id}:#{secret}")}"},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ]
    ]
    |> new()
  end

  # Accounts
  defdelegate client_credentials, to: __MODULE__.Accounts
  defdelegate authorization_url(scope \\ nil, state \\ nil), to: __MODULE__.Accounts
  defdelegate authorization_code(code, state), to: __MODULE__.Accounts
  defdelegate renew_token(refresh_token), to: __MODULE__.Accounts

  # Albums
  defdelegate get_album(album_id), to: __MODULE__.Albums

  # Artists
  defdelegate get_artist_top_track(artist_id), to: __MODULE__.Artists

  # Player
  defdelegate devices(scope), to: __MODULE__.Player
  defdelegate get_playback_state(scope, state), to: __MODULE__.Player
  defdelegate start_playback(scope, context \\ nil), to: __MODULE__.Player
  defdelegate pause_playback(scope), to: __MODULE__.Player
  defdelegate next_track(scope), to: __MODULE__.Player
  defdelegate previous_track(scope), to: __MODULE__.Player
  defdelegate set_repeat_mode(scope, state), to: __MODULE__.Player
  defdelegate toggle_playback_shuffle(scope, state), to: __MODULE__.Player
  defdelegate start_resume_playback(scope, album), to: __MODULE__.Player
  defdelegate add_item_to_playback_queue(scope, item), to: __MODULE__.Player

  # Playlists
  defdelegate get_playlist(playlist_id), to: __MODULE__.Playlists
  defdelegate get_library_playlists(scope, page \\ 1), to: __MODULE__.Playlists
  defdelegate create_playlist(scope, playlist), to: __MODULE__.Playlists
  defdelegate add_items_to_playlist(scope, id, tracks), to: __MODULE__.Playlists
  defdelegate replace_items_to_playlist(scope, id, tracks), to: __MODULE__.Playlists
  defdelegate remove_playlist_items(scope, id, tracks), to: __MODULE__.Playlists

  # Search
  defdelegate search_albums(query), to: __MODULE__.Search
  defdelegate search_artist(query), to: __MODULE__.Search

  # Users
  defdelegate get_user_profile(access_token), to: __MODULE__.Users
end
