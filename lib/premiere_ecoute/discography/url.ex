defprotocol PremiereEcoute.Discography.Links do
  @moduledoc false

  @fallback_to_any true
  @spec url(t(), atom()) :: String.t() | nil
  def url(value, provider)

  @fallback_to_any true
  @spec title(t()) :: String.t() | nil
  def title(value)
end

defimpl PremiereEcoute.Discography.Links, for: PremiereEcoute.Discography.Artist do
  def url(%{provider_ids: %{spotify: id}}, :spotify), do: "https://open.spotify.com/artist/#{id}"
  def url(%{provider_ids: %{deezer: id}}, :deezer), do: "https://www.deezer.com/artist/#{id}"
  def url(%{provider_ids: %{tidal: id}}, :tidal), do: "https://www.tidal.com/browse/artist/#{id}"
  def url(_, _), do: nil

  def title(%{name: name}), do: name
  def title(_), do: nil
end

defimpl PremiereEcoute.Discography.Links, for: PremiereEcoute.Discography.Album do
  def url(%{provider_ids: %{spotify: id}}, :spotify), do: "https://open.spotify.com/album/#{id}"
  def url(%{provider_ids: %{deezer: id}}, :deezer), do: "https://www.deezer.com/album/#{id}"
  def url(%{provider_ids: %{tidal: id}}, :tidal), do: "https://www.tidal.com/browse/album/#{id}"
  def url(_, _), do: nil

  def title(%{name: name}), do: name
  def title(_), do: nil
end

defimpl PremiereEcoute.Discography.Links, for: PremiereEcoute.Discography.Album.Track do
  def url(%{provider_ids: %{spotify: id}}, :spotify), do: "https://open.spotify.com/track/#{id}"
  def url(%{provider_ids: %{deezer: id}}, :deezer), do: "https://www.deezer.com/track/#{id}"
  def url(%{provider_ids: %{tidal: id}}, :tidal), do: "https://www.tidal.com/browse/track/#{id}"
  def url(_, _), do: nil

  def title(%{name: name}), do: name
  def title(_), do: nil
end

defimpl PremiereEcoute.Discography.Links, for: PremiereEcoute.Discography.Single do
  def url(%{provider_ids: %{spotify: id}}, :spotify), do: "https://open.spotify.com/track/#{id}"
  def url(%{provider_ids: %{deezer: id}}, :deezer), do: "https://www.deezer.com/track/#{id}"
  def url(%{provider_ids: %{tidal: id}}, :tidal), do: "https://www.tidal.com/browse/track/#{id}"
  def url(_, _), do: nil

  def title(%{name: name}), do: name
  def title(_), do: nil
end

defimpl PremiereEcoute.Discography.Links, for: PremiereEcoute.Discography.Playlist do
  def url(%{provider: :spotify, playlist_id: id}, _), do: "https://open.spotify.com/playlist/#{id}"
  def url(%{provider: :deezer, playlist_id: id}, _), do: "https://www.deezer.com/playlist/#{id}"
  def url(_, _), do: nil

  def title(%{title: title}), do: title
  def title(_), do: nil
end

defimpl PremiereEcoute.Discography.Links, for: Any do
  def url(_, _), do: nil
  def title(_), do: nil
end
