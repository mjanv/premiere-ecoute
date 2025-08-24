defmodule PremiereEcouteWeb.Billboards.ShowLive do
  @moduledoc """
  LiveView for managing a billboard.

  Allows the owner to:
  - Change billboard status (active/stopped)
  - View and delete submissions
  - Generate the billboard display
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteCore.Search
  alias PremiereEcouteWeb.Layouts

  @impl true
  def mount(%{"id" => billboard_id}, _session, socket) do
    case Billboards.get_billboard(billboard_id) do
      nil ->
        socket
        |> put_flash(:error, gettext("Billboard not found"))
        |> redirect(to: ~p"/home")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{} = billboard ->
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

        if current_user.id == billboard.user_id do
          cache_status = check_billboard_cache_status(billboard.billboard_id)
          sorted_submissions = sort_submissions_by_date(billboard.submissions || [])

          socket
          |> assign(:billboard, billboard)
          |> assign(:submissions, sorted_submissions)
          |> assign(:show_delete_modal, false)
          |> assign(:cache_status, cache_status)
          |> assign(:show_edit_modal, false)
          |> assign(:title_form, to_form(%{"title" => billboard.title}))
          |> assign(:search_query, "")
          |> assign(:review_filter, "all")
          |> assign(:filtered_submissions, filter_submissions(sorted_submissions, "", "all"))
          |> assign(:show_export_modal, false)
          |> assign(:spotify_playlists, [])
          |> assign(:selected_export_playlist, nil)
          |> assign(:export_count, 10)
          |> assign(:export_loading, false)
          |> assign(:export_error, nil)
          |> then(fn socket -> {:ok, socket} end)
        else
          socket
          |> put_flash(:error, gettext("You don't have permission to access this billboard"))
          |> redirect(to: ~p"/home")
          |> then(fn socket -> {:ok, socket} end)
        end
    end
  end

  @impl true
  def handle_event("activate", _params, socket) do
    case Billboards.activate_billboard(socket.assigns.billboard) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> put_flash(:info, gettext("Billboard activated! Users can now submit playlists."))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to activate billboard"))}
    end
  end

  @impl true
  def handle_event("stop", _params, socket) do
    case Billboards.stop_billboard(socket.assigns.billboard) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> put_flash(:info, gettext("Billboard stopped. No more submissions will be accepted."))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to stop billboard"))}
    end
  end

  @impl true
  def handle_event("remove_submission", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    case Billboards.remove_submission(socket.assigns.billboard, index) do
      {:ok, billboard} ->
        submissions = sort_submissions_by_date(billboard.submissions || [])
        filtered_submissions = filter_submissions(submissions, socket.assigns.search_query, socket.assigns.review_filter)

        socket
        |> assign(:billboard, billboard)
        |> assign(:submissions, submissions)
        |> assign(:filtered_submissions, filtered_submissions)
        |> put_flash(:info, gettext("Submission removed"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :invalid_index} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid submission"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove submission"))}
    end
  end

  @impl true
  def handle_event("toggle_review", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    case Billboards.toggle_submission_review(socket.assigns.billboard, index) do
      {:ok, billboard} ->
        submissions = sort_submissions_by_date(billboard.submissions || [])
        filtered_submissions = filter_submissions(submissions, socket.assigns.search_query, socket.assigns.review_filter)

        socket
        |> assign(:billboard, billboard)
        |> assign(:submissions, submissions)
        |> assign(:filtered_submissions, filtered_submissions)
        |> put_flash(:info, gettext("Submission review status updated"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :invalid_index} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid submission"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update review status"))}
    end
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    billboard = socket.assigns.billboard

    case Billboards.delete_billboard(billboard) do
      {:ok, _} ->
        socket
        |> put_flash(:info, gettext("Billboard deleted successfully"))
        |> redirect(to: ~p"/billboards")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        socket
        |> assign(:show_delete_modal, false)
        |> put_flash(:error, gettext("Failed to delete billboard"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("show_edit_modal", _params, socket) do
    {:noreply, assign(socket, :show_edit_modal, true)}
  end

  @impl true
  def handle_event("hide_edit_modal", _params, socket) do
    socket
    |> assign(:show_edit_modal, false)
    |> assign(:title_form, to_form(%{"title" => socket.assigns.billboard.title}))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_title", %{"title" => new_title}, socket) do
    billboard = socket.assigns.billboard

    case Billboards.update_billboard(billboard, %{title: new_title}) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> assign(:show_edit_modal, false)
        |> assign(:title_form, to_form(%{"title" => billboard.title}))
        |> put_flash(:info, gettext("Billboard title updated successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        socket
        |> assign(:title_form, to_form(changeset))
        |> put_flash(:error, gettext("Failed to update billboard title"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("validate_title", %{"title" => new_title}, socket) do
    {:noreply, assign(socket, :title_form, to_form(%{"title" => new_title}))}
  end

  @impl true
  def handle_event("search", params, socket) do
    query =
      case params do
        %{"query" => q} -> q
        _ -> ""
      end

    submissions = filter_submissions(socket.assigns.submissions, query, socket.assigns.review_filter)

    socket
    |> assign(:search_query, query)
    |> assign(:filtered_submissions, submissions)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("filter_review", params, socket) do
    filter =
      case params do
        %{"filter" => f} -> f
        _ -> "all"
      end

    submissions = socket.assigns.submissions
    search_query = socket.assigns.search_query
    filtered_submissions = filter_submissions(submissions, search_query, filter)

    socket
    |> assign(:review_filter, filter)
    |> assign(:filtered_submissions, filtered_submissions)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("show_export_modal", _params, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if current_user do
      # AIDEV-NOTE: Load user's library playlists from database when opening export modal
      library_playlists = LibraryPlaylist.all(where: [user_id: current_user.id, provider: :spotify])

      {:noreply, assign(socket, show_export_modal: true, spotify_playlists: library_playlists, export_error: nil)}
    else
      {:noreply, put_flash(socket, :error, gettext("Please log in to export playlists"))}
    end
  end

  @impl true
  def handle_event("hide_export_modal", _params, socket) do
    socket
    |> assign(:show_export_modal, false)
    |> assign(:selected_export_playlist, nil)
    |> assign(:export_count, 10)
    |> assign(:export_error, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("select_export_playlist", %{"playlist_id" => playlist_id}, socket) do
    {:noreply, assign(socket, :selected_export_playlist, playlist_id)}
  end

  @impl true
  def handle_event("update_export_count", params, socket) do
    count_str =
      case params do
        %{"count" => count} -> count
        %{"value" => count} -> count
        %{count: count} -> count
        %{value: count} -> count
        _ -> nil
      end

    case count_str && Integer.parse(count_str) do
      {count, _} when count > 0 and count <= 100 ->
        {:noreply, assign(socket, :export_count, count)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_tracks", _params, socket) do
    billboard = socket.assigns.billboard
    current_scope = socket.assigns.current_scope
    selected_playlist_id = socket.assigns.selected_export_playlist
    export_count = socket.assigns.export_count

    if selected_playlist_id do
      socket = assign(socket, :export_loading, true)

      # AIDEV-NOTE: Perform export in background task to avoid blocking UI
      pid = self()

      Task.start(fn ->
        case get_top_tracks_with_generation(billboard, export_count) do
          {:ok, tracks} ->
            case export_tracks_to_playlist(current_scope, selected_playlist_id, tracks) do
              {:ok, _} -> send(pid, {:export_success, export_count})
              {:error, reason} -> send(pid, {:export_error, reason})
            end

          {:error, message} ->
            send(pid, {:export_error, message})
        end
      end)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :export_error, gettext("Please select a playlist"))}
    end
  end

  # Helper functions
  defp filter_submissions(submissions, query, review_filter) do
    reviewed =
      case review_filter do
        "all" -> nil
        "reviewed" -> true
        "unreviewed" -> false
      end

    submissions
    |> Search.filter(query, ["pseudo", "url"])
    |> Search.flag([{"reviewed", reviewed}])
    |> Search.sort(:added_at, :desc)
  end

  defp sort_submissions_by_date(submissions) do
    Search.sort(submissions, :added_at, :desc)
  end

  # AIDEV-NOTE: Check if billboard is available in cache
  defp check_billboard_cache_status(billboard_id) do
    case Cache.get(:billboards, billboard_id) do
      {:ok, nil} -> :not_ready
      {:ok, _} -> :ready
      {:error, _} -> :not_ready
    end
  end

  # AIDEV-NOTE: Handle export task completion messages
  @impl true
  def handle_info({:export_success, count}, socket) do
    socket
    |> assign(:export_loading, false)
    |> assign(:show_export_modal, false)
    |> assign(:selected_export_playlist, nil)
    |> assign(:export_count, 10)
    |> assign(:export_error, nil)
    |> put_flash(:info, gettext("Successfully exported top %{count} tracks to your Spotify playlist!", count: count))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:export_error, reason}, socket) do
    error_message =
      case reason do
        %{"error" => %{"message" => msg}} -> msg
        msg when is_binary(msg) -> msg
        _ -> gettext("Failed to export tracks to Spotify playlist")
      end

    socket
    |> assign(:export_loading, false)
    |> assign(:export_error, error_message)
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: Export tracks to playlist using 3-step process: get -> remove -> add
  defp export_tracks_to_playlist(scope, playlist_id, tracks) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id),
         {:ok, _} <- remove_all_playlist_tracks(scope, playlist_id, playlist),
         {:ok, result} <- Apis.spotify().add_items_to_playlist(scope, playlist_id, tracks) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Failed to export tracks: #{inspect(error)}"}
    end
  end

  # AIDEV-NOTE: Remove all existing tracks from playlist
  defp remove_all_playlist_tracks(_scope, _playlist_id, playlist) when is_nil(playlist.tracks) or playlist.tracks == [] do
    {:ok, nil}
  end

  defp remove_all_playlist_tracks(scope, playlist_id, _playlist) do
    # AIDEV-NOTE: Get current playlist snapshot for removal
    case Apis.spotify().get_playlist(playlist_id) do
      {:ok, current_playlist} ->
        tracks_to_remove = current_playlist.tracks || []

        if length(tracks_to_remove) > 0 do
          # AIDEV-NOTE: Use updated API without snapshot parameter
          Apis.spotify().remove_playlist_items(scope, playlist_id, tracks_to_remove)
        else
          {:ok, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # AIDEV-NOTE: Get top N tracks, generating billboard if not in cache
  defp get_top_tracks_with_generation(billboard, count) do
    case Cache.get(:billboards, billboard.billboard_id) do
      {:ok, cached_billboard} when not is_nil(cached_billboard) ->
        extract_top_tracks(cached_billboard, count)

      _ ->
        # AIDEV-NOTE: Billboard not in cache, generate it
        urls = Enum.map(billboard.submissions, fn %{"url" => url} -> url end)

        if length(urls) > 0 do
          case Billboards.generate_billboard(urls, callback: fn _text, _progress -> :ok end) do
            {:ok, generated_billboard} ->
              # Cache the generated billboard
              Cache.put(:billboards, billboard.billboard_id, generated_billboard)
              extract_top_tracks(generated_billboard, count)

            {:error, reason} ->
              {:error, "Failed to generate billboard: #{reason}"}
          end
        else
          {:error, gettext("No valid submissions found")}
        end
    end
  end

  # AIDEV-NOTE: Extract top N tracks from billboard data
  defp extract_top_tracks(billboard, count) do
    tracks = billboard.track || []

    top_tracks =
      tracks
      |> Enum.sort_by(& &1.rank)
      |> Enum.take(count)

    if length(top_tracks) > 0 do
      # AIDEV-NOTE: Convert billboard track format to Spotify API format
      spotify_tracks =
        Enum.map(top_tracks, fn track_group ->
          # Get the first track from the group (they're all the same track)
          track = track_group.track
          %{track_id: track.track_id}
        end)

      {:ok, spotify_tracks}
    else
      {:error, gettext("No tracks found in billboard")}
    end
  end
end
