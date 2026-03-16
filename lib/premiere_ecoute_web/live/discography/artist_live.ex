defmodule PremiereEcouteWeb.Discography.ArtistLive do
  @moduledoc """
  Artist detail page — shows artist metadata and listening sessions that featured their music.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    artist = Discography.get_artist_by_slug(slug)

    if is_nil(artist) do
      {:ok, push_navigate(socket, to: ~p"/discography/artists")}
    else
      sessions = ListeningSession.list_for_artist(artist.id)
      albums = Discography.list_albums_for_artist(artist.id)
      singles = Discography.list_singles_for_artist(artist.id)

      {:ok,
       socket
       |> assign(:artist, artist)
       |> assign(:sessions, sessions)
       |> assign(:albums, albums)
       |> assign(:singles, singles)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
