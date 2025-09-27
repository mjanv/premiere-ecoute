defmodule PremiereEcouteWeb.Festivals.PosterLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Festivals

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      id = socket.assigns.current_scope.user.id
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "festival:#{id}")
    end

    socket
    |> assign(:uploaded_files, [])
    |> assign(:festival, AsyncResult.loading())
    |> assign(:tracks, AsyncResult.loading())
    |> assign(:export, AsyncResult.loading())
    |> allow_upload(:poster, accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 10_000_000)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :poster, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    [{url, path} | _] =
      consume_uploaded_entries(socket, :poster, fn %{path: path}, _entry ->
        filename = "festival_#{System.unique_integer([:positive])}_#{Path.basename(path)}"
        dest = Path.join(["priv/static/uploads", filename])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, {~p"/uploads/#{filename}", dest}}
      end)

    scope = socket.assigns.current_scope

    socket
    |> update(:uploaded_files, &(&1 ++ [url]))
    |> start_async(:analyze_poster, fn -> Festivals.analyze_poster(scope, path) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("create_festival_playlist", _params, socket) do
    %{current_scope: scope, festival: festival, tracks: tracks, export: export} = socket.assigns

    socket
    |> assign(:export, AsyncResult.ok(export, true))
    |> start_async(:export, fn -> Festivals.create_festival_playlist(scope, festival.result, tracks.result) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:partial, partial_festival}, %{assigns: %{festival: festival}} = socket) do
    socket
    |> assign(:festival, AsyncResult.ok(festival, partial_festival))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_async(
        :analyze_poster,
        {:ok, {:ok, final_festival}},
        %{assigns: %{festival: festival, current_scope: scope}} = socket
      ) do
    socket
    |> assign(:festival, AsyncResult.ok(festival, final_festival))
    |> start_async(:tracks, fn -> Festivals.find_tracks(scope, final_festival) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_async(:tracks, {:ok, festival}, %{assigns: %{tracks: tracks}} = socket) do
    found_tracks =
      festival.concerts
      |> Enum.map(fn
        %{track: nil} -> nil
        %{track: track} -> %Playlist.Track{track_id: track.track_id, name: track.name}
      end)
      |> Enum.reject(&is_nil/1)

    socket
    |> assign(:tracks, AsyncResult.ok(tracks, found_tracks))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:export, {:ok, result}, %{assigns: %{export: export}} = socket) do
    case result do
      {:ok, _} ->
        socket
        |> assign(:export, AsyncResult.ok(export, false))
        |> put_flash(:success, gettext("Successfully created festival playlist!"))

      {:error, reason} ->
        socket
        |> assign(:export, AsyncResult.failed(export, reason))
        |> put_flash(:error, gettext("Failed to create playlist: %{reason}", reason: reason))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(task, result, socket) do
    Logger.error("Received from task #{task}: #{inspect(result)}")
    {:noreply, socket}
  end
end
