defmodule PremiereEcouteWeb.Discography.BillboardLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography.Billboard

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      playlist_input: "",
      tracks: [],
      loading: false,
      error: nil,
      ascii_header: Billboard.generate_ascii_header(),
      progress: 0,
      progress_text: ""
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
      # Start async task with progress callback
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
          loading: true,
          error: nil,
          tracks: [],
          task: task,
          progress: 0,
          progress_text: "Starting..."
        )

      {:noreply, socket}
    else
      socket = assign(socket, error: "Please enter at least one playlist URL")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_results", _params, socket) do
    socket =
      assign(socket,
        tracks: [],
        loading: false,
        error: nil,
        task: nil,
        progress: 0,
        progress_text: ""
      )

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

          socket =
            assign(socket,
              tracks: formatted_tracks,
              loading: false,
              error: nil,
              task: nil,
              progress: 0,
              progress_text: ""
            )

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
