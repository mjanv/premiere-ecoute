defmodule PremiereEcouteWeb.Sessions.AlbumPickSubmissionLive do
  @moduledoc """
  Public LiveView for submitting albums to a streamer's random pick list.

  Accessible to unauthenticated users. Searches Spotify albums and stores
  the selected one as a viewer-sourced album pick entry.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions.AlbumPicks

  @impl true
  def mount(%{"user_id" => user_id_str}, _session, socket) do
    with {user_id, ""} <- Integer.parse(user_id_str),
         streamer <- Accounts.get_user!(user_id),
         true <- streamer.role in [:streamer, :admin] do
      socket
      |> assign(:streamer, streamer)
      |> assign(:search_form, to_form(%{"query" => ""}))
      |> assign(:search_albums, AsyncResult.ok([]))
      |> assign(:selected_album, nil)
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
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_albums, AsyncResult.loading())
    |> start_async(:search, fn -> PremiereEcoute.Apis.spotify().search_albums(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_albums", _params, socket) do
    {:noreply, assign(socket, :search_albums, AsyncResult.ok([]))}
  end

  def handle_event("clear_search_results", _params, socket) do
    {:noreply, assign(socket, :search_albums, AsyncResult.ok([]))}
  end

  def handle_event("select_album", %{"album_id" => album_id}, socket) do
    album =
      case socket.assigns.search_albums do
        %{result: albums} when is_list(albums) -> Enum.find(albums, &(&1.album_id == album_id))
        _ -> nil
      end

    socket
    |> assign(:selected_album, album)
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:error_message, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("clear_selected_album", _params, socket) do
    {:noreply, assign(socket, :selected_album, nil)}
  end

  def handle_event("submit_album", %{"pseudo" => pseudo}, socket) do
    pseudo = String.trim(pseudo)
    streamer = socket.assigns.streamer

    case socket.assigns.selected_album do
      nil ->
        {:noreply, assign(socket, error_message: gettext("Please select an album first."))}

      album ->
        attrs = %{
          album_id: album.album_id,
          name: album.name,
          artist: album.artist,
          cover_url: album.cover_url
        }

        case AlbumPicks.add_viewer_entry(streamer.id, attrs, pseudo) do
          {:ok, pick} ->
            PremiereEcoute.PubSub.broadcast("album_picks:#{streamer.id}", {:pick_added, pick})

            socket
            |> assign(:search_form, to_form(%{"query" => ""}))
            |> assign(:search_albums, AsyncResult.ok([]))
            |> assign(:selected_album, nil)
            |> assign(:success_message, gettext("Album submitted successfully!"))
            |> assign(:error_message, nil)
            |> then(fn socket -> {:noreply, socket} end)

          {:error, :already_exists} ->
            {:noreply, assign(socket, error_message: gettext("This album is already in the list"))}

          {:error, _} ->
            {:noreply, assign(socket, error_message: gettext("Failed to submit album. Please try again."))}
        end
    end
  end

  @impl true
  def handle_async(:search, {:ok, {:ok, albums}}, socket) do
    {:noreply, assign(socket, :search_albums, AsyncResult.ok(albums))}
  end

  def handle_async(:search, {:ok, {:error, _reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, :error))
    |> assign(:error_message, gettext("Search failed. Please try again."))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:exit, _reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, :error))
    |> assign(:error_message, gettext("Search failed. Please try again."))
    |> then(fn socket -> {:noreply, socket} end)
  end
end
