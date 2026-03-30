defmodule PremiereEcouteWeb.Discography.ArtistLive do
  @moduledoc """
  Artist detail page — shows artist metadata and listening sessions that featured their music.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Wantlists

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    artist = Discography.get_artist_by_slug(slug)

    if is_nil(artist) do
      {:ok, push_navigate(socket, to: ~p"/discography/artists")}
    else
      sessions = ListeningSession.list_for_artist(artist.id)
      albums = Discography.list_albums_for_artist(artist.id)
      singles = Discography.list_singles_for_artist(artist.id)

      current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

      in_wantlist =
        if current_user,
          do: Wantlists.in_wantlist?(current_user.id, :artist, artist.id),
          else: false

      {:ok,
       socket
       |> assign(:artist, artist)
       |> assign(:sessions, sessions)
       |> assign(:albums, albums)
       |> assign(:singles, singles)
       |> assign(:in_wantlist, in_wantlist)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_wantlist_artist", _params, socket) do
    user = socket.assigns.current_scope.user
    artist = socket.assigns.artist

    if socket.assigns.in_wantlist do
      case Wantlists.remove_item(user.id, :artist, artist.id) do
        {:ok, _} -> {:noreply, assign(socket, :in_wantlist, false)}
        {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Could not remove from wantlist"))}
      end
    else
      case Wantlists.add_item(user.id, :artist, artist.id) do
        {:ok, _} -> {:noreply, assign(socket, :in_wantlist, true)}
        {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Could not add to wantlist"))}
      end
    end
  end
end
