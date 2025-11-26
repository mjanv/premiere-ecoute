defmodule PremiereEcouteWeb.Sessions.AlbumSelectionLive do
  @moduledoc """
  Album/playlist selection LiveView for session creation.

  Provides interface to search Spotify albums or select user playlists asynchronously, configure vote options (0-10, 1-5, smash/pass), and create new listening sessions with selected content.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    PremiereEcoute.PubSub.subscribe("listening_sessions")

    socket
    |> assign(:source_type, nil)
    |> assign(:search_form, to_form(%{"query" => ""}))
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.ok(nil))
    |> assign(:user_playlists, AsyncResult.ok([]))
    |> assign(:selected_playlist, AsyncResult.ok(nil))
    |> assign(:current_scope, socket.assigns[:current_scope] || %{})
    |> assign(:vote_options_preset, nil)
    |> assign(:vote_options_configured, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_albums, AsyncResult.loading())
    |> start_async(:search, fn -> PremiereEcoute.Apis.spotify().search_albums(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_albums", _params, socket) do
    # Clear search results when query is empty or too short
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("clear_search_results", _params, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_source", %{"source" => source}, socket) do
    socket
    |> assign(:source_type, source)
    # Clear previous searches
    |> assign(:search_albums, AsyncResult.ok([]))
    # Clear previous selection
    |> assign(:selected_album, AsyncResult.ok(nil))
    |> assign(:selected_playlist, AsyncResult.ok(nil))
    # Reset search form
    |> assign(:search_form, to_form(%{"query" => ""}))
    # Reset vote options state
    |> assign(:vote_options_preset, nil)
    |> assign(:vote_options_configured, false)
    # Load playlists if playlist source is selected
    |> maybe_load_playlists(source)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_album", %{"album_id" => album_id}, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.loading())
    |> start_async(:select, fn -> PremiereEcoute.Apis.spotify().get_album(album_id) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_playlist", %{"playlist_id" => ""}, socket) do
    # Clear selection when empty value is selected
    socket
    |> assign(:selected_playlist, AsyncResult.ok(nil))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_playlist", %{"playlist_id" => playlist_id}, socket) do
    # Find the library playlist from the loaded playlists
    case socket.assigns.user_playlists do
      %{result: playlists} when is_list(playlists) ->
        case Enum.find(playlists, fn p -> p.playlist_id == playlist_id end) do
          nil ->
            socket
            |> assign(:selected_playlist, AsyncResult.failed(socket.assigns.selected_playlist, {:error, "Playlist not found"}))
            |> put_flash(:error, "Playlist not found")
            |> then(fn socket -> {:noreply, socket} end)

          playlist ->
            socket
            |> assign(:selected_playlist, AsyncResult.ok(playlist))
            |> then(fn socket -> {:noreply, socket} end)
        end

      _ ->
        socket
        |> assign(:selected_playlist, AsyncResult.failed(socket.assigns.selected_playlist, {:error, "No playlists loaded"}))
        |> put_flash(:error, "Please select playlist source first")
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("prepare_session", _params, %{assigns: %{selected_album: nil, selected_playlist: %{result: nil}}} = socket) do
    {:noreply, put_flash(socket, :error, "Please select an album or playlist first")}
  end

  def handle_event("vote_options_preset_change", %{"preset" => preset}, socket) do
    case preset do
      "" ->
        # Handle empty selection - don't mark as configured
        socket
        |> assign(:vote_options_preset, nil)
        |> assign(:vote_options_configured, false)
        |> then(fn socket -> {:noreply, socket} end)

      _ ->
        socket
        |> assign(:vote_options_preset, preset)
        |> assign(:vote_options_configured, true)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event(
        "prepare_session",
        _params,
        %{assigns: %{selected_album: %{result: album}}} = socket
      )
      when not is_nil(album) do
    vote_options = get_vote_options(socket.assigns)

    %PrepareListeningSession{
      source: :album,
      user_id: get_user_id(socket),
      album_id: album.album_id,
      vote_options: vote_options
    }
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/sessions/#{session}")
      {:error, _} -> put_flash(socket, :error, "Cannot create the listening session")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event(
        "prepare_session",
        _params,
        %{assigns: %{selected_playlist: %{result: playlist}}} = socket
      )
      when not is_nil(playlist) do
    %PrepareListeningSession{
      source: :playlist,
      user_id: get_user_id(socket),
      playlist_id: playlist.playlist_id,
      vote_options: get_vote_options(socket.assigns)
    }
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/sessions/#{session}")
      {:error, _} -> put_flash(socket, :error, "Cannot create the listening session")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_async(:search, {:ok, result}, %{assigns: assigns} = socket) do
    case result do
      {:ok, albums} ->
        socket
        |> assign(:search_albums, AsyncResult.ok(albums))

      {:error, reason} ->
        socket
        |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
        |> put_flash(:error, "Search failed. Please try again.")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
    |> put_flash(:error, "Search failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, {:ok, album}}, socket) do
    socket
    |> assign(:selected_album, AsyncResult.ok(album))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:load_playlists, {:ok, {:ok, playlists}}, socket) do
    socket
    |> assign(:user_playlists, AsyncResult.ok(playlists))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:load_playlists, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:user_playlists, AsyncResult.failed(assigns.user_playlists, {:error, reason}))
    |> put_flash(:error, "Failed to load playlists. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:load_playlists, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:user_playlists, AsyncResult.failed(assigns.user_playlists, {:error, reason}))
    |> put_flash(:error, "Failed to load playlists. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def get_vote_options(%{vote_options_preset: "0-10"}), do: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
  def get_vote_options(%{vote_options_preset: "1-5"}), do: ["1", "2", "3", "4", "5"]
  def get_vote_options(%{vote_options_preset: "smash-pass"}), do: ["smash", "pass"]
  def get_vote_options(%{vote_options_preset: nil}), do: []

  # default fallback - return empty for any other case
  def get_vote_options(_), do: []

  defp get_user_id(socket) do
    case socket.assigns.current_scope do
      %{user: %{id: user_id}} -> user_id
      _ -> nil
    end
  end

  defp maybe_load_playlists(socket, "playlist") do
    case socket.assigns.current_scope do
      %{user: user} ->
        socket
        |> assign(:user_playlists, AsyncResult.loading())
        |> start_async(:load_playlists, fn -> {:ok, PremiereEcoute.Playlists.all_for_user(user)} end)

      _ ->
        socket
        |> assign(:user_playlists, AsyncResult.failed(socket.assigns.user_playlists, {:error, "No authentication"}))
        |> put_flash(:error, "Please authenticate to view your playlists")
    end
  end

  defp maybe_load_playlists(socket, _), do: socket
end
