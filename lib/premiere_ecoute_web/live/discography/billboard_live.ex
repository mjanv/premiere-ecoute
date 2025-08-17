defmodule PremiereEcouteWeb.Discography.BillboardLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography.Billboard

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      playlist_form: to_form(%{"playlist_input" => nil}),
      tracks: [],
      artists: [],
      years: [],
      # AIDEV-NOTE: Track display mode (:track, :artist, or :year)
      display_mode: :track,
      loading: false,
      error: nil,
      ascii_header: Billboard.generate_ascii_header(),
      progress: 0,
      progress_text: "",
      selected_track: nil,
      selected_artist: nil,
      selected_year: nil,
      show_modal: false
    )
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_billboard", %{"playlist_input" => playlist_input}, socket) do
    playlist_urls = parse_playlist_urls(playlist_input)

    if length(playlist_urls) > 0 do
      live_view_pid = self()

      task =
        Task.async(fn ->
          progress_callback = fn text, progress ->
            send(live_view_pid, {:progress_update, text, progress})
          end

          Billboard.generate_billboard(playlist_urls, progress_callback: progress_callback)
        end)

      socket =
        assign(socket,
          playlist_form: to_form(%{"playlist_input" => playlist_input}),
          loading: true,
          error: nil,
          tracks: [],
          task: task,
          progress: 0,
          progress_text: "Starting..."
        )
        |> push_event("set_loading", %{loading: true})

      {:noreply, socket}
    else
      socket = assign(socket, error: "Please enter at least one playlist URL")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("generate_billboard", _params, socket) do
    # AIDEV-NOTE: Handle case where form is submitted without playlist_input
    socket = assign(socket, error: "Please enter at least one playlist URL")
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_results", _params, socket) do
    socket =
      assign(socket,
        tracks: [],
        artists: [],
        years: [],
        loading: false,
        error: nil,
        task: nil,
        progress: 0,
        progress_text: ""
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("playlist_loaded", %{"value" => value}, socket) do
    {:noreply, assign(socket, playlist_form: to_form(%{"playlist_input" => value}))}
  end

  @impl true
  def handle_event("update_playlist_input", %{"playlist_input" => playlist_input}, socket) do
    {:noreply, assign(socket, playlist_form: to_form(%{"playlist_input" => playlist_input}))}
  end

  @impl true
  def handle_event("select_track", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    selected_track = Enum.find(socket.assigns.tracks, &(&1.rank == rank))

    {:noreply, assign(socket, selected_track: selected_track, show_modal: true)}
  end

  @impl true
  def handle_event("select_artist", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    selected_artist = Enum.find(socket.assigns.artists, &(&1.rank == rank))

    {:noreply, assign(socket, selected_artist: selected_artist, show_modal: true)}
  end

  @impl true
  def handle_event("select_year", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    selected_year = Enum.find(socket.assigns.years, &(&1.display_rank == rank))

    {:noreply, assign(socket, selected_year: selected_year, show_modal: true)}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    display_mode = String.to_existing_atom(mode)
    {:noreply, assign(socket, display_mode: display_mode)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_track: nil, selected_artist: nil, selected_year: nil, show_modal: false)}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, result}, socket) do
    # Only handle if this ref matches our current task
    if socket.assigns[:task] && socket.assigns.task.ref == ref do
      # Task completed
      Process.demonitor(ref, [:flush])

      case result do
        {:ok, tracks} ->
          formatted_tracks =
            tracks
            |> Enum.with_index(1)
            |> Enum.map(fn {track, rank} ->
              Billboard.format_track_entry(track, rank)
            end)

          # AIDEV-NOTE: Generate artist and year aggregation from tracks data
          formatted_artists = Billboard.generate_artist_billboard(tracks)
          formatted_years = Billboard.generate_year_billboard(tracks)

          socket =
            assign(socket,
              tracks: formatted_tracks,
              artists: formatted_artists,
              years: formatted_years,
              loading: false,
              error: nil,
              task: nil,
              progress: 0,
              progress_text: ""
            )
            |> push_event("set_loading", %{loading: false})

          {:noreply, socket}

        {:error, reason} ->
          socket =
            assign(socket,
              loading: false,
              error: "Failed to generate billboard: #{reason}",
              task: nil,
              progress: 0,
              progress_text: ""
            )
            |> push_event("set_loading", %{loading: false})

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task crashed or was killed
    socket =
      assign(socket,
        loading: false,
        error: "Failed to generate billboard: request was interrupted",
        task: nil,
        progress: 0,
        progress_text: ""
      )
      |> push_event("set_loading", %{loading: false})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:progress_update, text, progress}, socket) do
    socket = assign(socket, progress: progress, progress_text: text)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Parse playlist URLs from textarea input, handling various formats
  defp parse_playlist_urls(input) do
    input
    |> String.split(["\n", "\r\n", "\r"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn url ->
      String.starts_with?(url, "http") and
        (String.contains?(url, "spotify.com/playlist") or String.contains?(url, "deezer.com"))
    end)
  end
end
