defmodule PremiereEcouteWeb.Sessions.AlbumPickSubmissionLive do
  @moduledoc """
  Public LiveView for submitting albums to a streamer's random pick pool.

  Accessible to unauthenticated users. Accepts a Spotify album URL, fetches
  album metadata, and stores it as a viewer-sourced album pick entry.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions.AlbumPicks

  @spotify_album_url_regex ~r|https://open\.spotify\.com/album/([a-zA-Z0-9]+)|

  @impl true
  def mount(%{"user_id" => user_id_str}, _session, socket) do
    with {user_id, ""} <- Integer.parse(user_id_str),
         streamer <- Accounts.get_user!(user_id),
         true <- streamer.role in [:streamer, :admin] do
      socket
      |> assign(:streamer, streamer)
      |> assign(:url, "")
      |> assign(:pseudo, "")
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
      |> then(fn socket -> {:ok, socket} end)
    else
      _ ->
        socket
        |> put_flash(:error, gettext("Streamer not found"))
        |> redirect(to: ~p"/")
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, url: Map.get(params, "url", ""), pseudo: Map.get(params, "pseudo", ""), error_message: nil)}
  end

  @impl true
  def handle_event("submit", params, socket) do
    url = Map.get(params, "url", "") |> String.trim()
    pseudo = Map.get(params, "pseudo", "") |> String.trim()
    streamer = socket.assigns.streamer

    case parse_album_id(url) do
      {:ok, album_id} ->
        case PremiereEcoute.Apis.spotify().get_album(album_id) do
          {:ok, album} ->
            attrs = %{
              album_id: album.album_id,
              name: album.name,
              artist: album.artist,
              cover_url: album.cover_url
            }

            case AlbumPicks.add_viewer_entry(streamer.id, attrs, pseudo) do
              {:ok, _pick} ->
                socket
                |> assign(:url, "")
                |> assign(:pseudo, "")
                |> assign(:success_message, gettext("Album submitted successfully!"))
                |> assign(:error_message, nil)
                |> then(fn socket -> {:noreply, socket} end)

              {:error, :already_exists} ->
                {:noreply, assign(socket, error_message: gettext("This album is already in the pool"))}

              {:error, _} ->
                {:noreply, assign(socket, error_message: gettext("Failed to add album. Please try again."))}
            end

          {:error, _} ->
            {:noreply, assign(socket, error_message: gettext("Could not fetch album from Spotify. Check the URL and try again."))}
        end

      {:error, message} ->
        {:noreply, assign(socket, error_message: message)}
    end
  end

  defp parse_album_id(url) do
    case Regex.run(@spotify_album_url_regex, url, capture: :all_but_first) do
      [album_id] -> {:ok, album_id}
      _ -> {:error, gettext("Please use a valid Spotify album URL (e.g. https://open.spotify.com/album/...)")}
    end
  end
end
