defmodule PremiereEcoute.Discography do
  @moduledoc """
  Context module for managing music discography data.

  The Discography context handles the storage and retrieval of music catalog data
  including albums and tracks sourced from Spotify's API. This data forms the foundation
  for listening sessions where users can discover, rate, and discuss music.

  ## Core Entities

  - `Album` - Represents a music album with metadata and associated tracks
  - `Track` - Individual songs within an album with track-specific information
  """

  import Ecto.Query

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Single

  # Album
  defdelegate create_album(album), to: Album, as: :create
  defdelegate get_album(id), to: Album, as: :get
  defdelegate get_album_by_slug(id), to: Album, as: :get_album_by_slug
  defdelegate list_albums(), to: Album, as: :all

  @spec last_albums(non_neg_integer()) :: [Album.t()]
  def last_albums(n \\ 5), do: Album.all(order_by: [desc: :inserted_at], limit: n) |> Enum.map(&Album.put_artist/1)

  # Artist
  defdelegate get_artist_by_slug(slug), to: Artist, as: :get_by_slug
  defdelegate list_artists(), to: Artist, as: :all

  @spec last_artists(non_neg_integer()) :: [Artist.t()]
  def last_artists(n \\ 5), do: Artist.all(order_by: [desc: :inserted_at], limit: n)

  @spec list_albums_for_artist(integer()) :: [Album.t()]
  def list_albums_for_artist(artist_id) do
    Album
    |> join(:inner, [a], aa in "album_artists", on: aa.album_id == a.id)
    |> where([_a, aa], aa.artist_id == ^artist_id)
    |> order_by([a, _aa], desc: a.inserted_at)
    |> PremiereEcoute.Repo.all()
    |> Album.preload()
    |> Enum.map(&Album.put_artist/1)
  end

  @spec list_singles_for_artist(integer()) :: [Single.t()]
  def list_singles_for_artist(artist_id) do
    Single
    |> join(:inner, [s], sa in "single_artists", on: sa.single_id == s.id)
    |> where([_s, sa], sa.artist_id == ^artist_id)
    |> order_by([s, _sa], desc: s.inserted_at)
    |> PremiereEcoute.Repo.all()
    |> Single.preload()
    |> Enum.map(&Single.put_artist/1)
  end

  # Single
  defdelegate get_single(id), to: Single, as: :get
  defdelegate get_single_by_slug(slug), to: Single, as: :get_by_slug
  defdelegate list_singles(), to: Single, as: :all

  @spec last_singles(non_neg_integer()) :: [Single.t()]
  def last_singles(n \\ 5), do: Single.all(order_by: [desc: :inserted_at], limit: n) |> Enum.map(&Single.put_artist/1)

  # Playlist
  defdelegate create_playlist(playlist), to: Playlist, as: :create

  @spec title(any()) :: String.t() | nil
  def title(%{title: title}), do: title
  def title(%{name: name}), do: name
  def title(_), do: nil

  @spec url(any()) :: String.t() | nil
  def url(%Album{provider_ids: ids}) do
    cond do
      id = Map.get(ids, :spotify) -> "https://open.spotify.com/album/#{id}"
      id = Map.get(ids, :deezer) -> "https://www.deezer.com/album/#{id}"
      true -> nil
    end
  end

  def url(%Album.Track{provider_ids: ids}) do
    cond do
      id = Map.get(ids, :spotify) -> "https://open.spotify.com/track/#{id}"
      id = Map.get(ids, :deezer) -> "https://www.deezer.com/track/#{id}"
      true -> nil
    end
  end

  def url(%Single{provider_ids: ids}) do
    cond do
      id = Map.get(ids, :spotify) -> "https://open.spotify.com/track/#{id}"
      id = Map.get(ids, :deezer) -> "https://www.deezer.com/track/#{id}"
      true -> nil
    end
  end

  def url(%Playlist{provider: :spotify, playlist_id: id}), do: "https://open.spotify.com/playlist/#{id}"
  def url(%Playlist{provider: :deezer, playlist_id: id}), do: "https://www.deezer.com/playlist/#{id}"

  def url(_), do: nil

  @spec url(any(), atom()) :: String.t() | nil
  def url(%Album{provider_ids: ids}, :spotify), do: "https://open.spotify.com/album/#{ids[:spotify]}"
  def url(%Album{provider_ids: ids}, :deezer), do: "https://www.deezer.com/album/#{ids[:deezer]}"
  def url(%Album.Track{provider_ids: ids}, :spotify), do: "https://open.spotify.com/track/#{ids[:spotify]}"
  def url(%Album.Track{provider_ids: ids}, :deezer), do: "https://www.deezer.com/track/#{ids[:deezer]}"
  def url(%Single{provider_ids: ids}, :spotify), do: "https://open.spotify.com/track/#{ids[:spotify]}"
  def url(%Single{provider_ids: ids}, :deezer), do: "https://www.deezer.com/track/#{ids[:deezer]}"
  def url(_, _), do: nil
end
