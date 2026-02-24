defmodule PremiereEcoute.Apis.MusicProvider do
  @moduledoc false

  defmodule Oauth do
    @moduledoc false

    @callback client_credentials() :: {:ok, map()} | {:error, any()}
    @callback authorization_url(scope :: String.t() | nil, state :: String.t() | nil) :: String.t()
    @callback renew_token(refresh_token :: String.t()) :: {:ok, map()} | {:error, any()}
  end

  defmodule Albums do
    @moduledoc false

    alias PremiereEcoute.Discography.Album
    alias PremiereEcoute.Discography.Album.Track

    @callback get_album(album_id :: String.t()) :: {:ok, Album.t()} | {:error, term()}
    @callback get_track(track_id :: String.t()) :: {:ok, Track.t()} | {:error, term()}
  end

  defmodule Playlists do
    @moduledoc false

    alias PremiereEcoute.Discography.Playlist

    @callback get_playlist(playlist_id :: String.t()) :: {:ok, Playlist.t()} | {:error, term()}
  end
end
