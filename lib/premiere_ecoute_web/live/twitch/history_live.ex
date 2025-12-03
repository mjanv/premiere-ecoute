defmodule PremiereEcouteWeb.Twitch.HistoryLive do
  @moduledoc """
  Landing page for uploading Twitch history data.

  This is an unauthenticated page where users can drop a Twitch data export zip file.
  After upload, the user is redirected to a separate view page to see the parsed data.
  """

  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> allow_upload(:request, accept: ~w(.zip), max_file_size: 999_000_000, max_entries: 1)
    |> assign(:upload_error, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :request, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    uploaded_paths =
      consume_uploaded_entries(socket, :request, fn %{path: path}, _entry ->
        dest = Path.join("priv/static/uploads", Path.basename(path))
        File.cp!(path, dest)
        {:ok, Path.basename(dest)}
      end)

    case uploaded_paths do
      [filename | _] ->
        {:noreply, push_navigate(socket, to: ~p"/twitch/history/#{filename}")}

      [] ->
        {:noreply, assign(socket, upload_error: "Failed to upload file")}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket.assigns.uploads.request
    |> Map.get(:entries)
    |> List.first()
    |> case do
      nil ->
        assign(socket, :upload_error, nil)

      entry ->
        socket.assigns.uploads.request
        |> upload_errors(entry)
        |> case do
          [] ->
            assign(socket, :upload_error, nil)

          errors ->
            Enum.reduce(errors, socket, fn error, socket ->
              assign(socket, :upload_error, error_to_string(error))
            end)
        end
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def error_to_string(:too_large), do: "File is too large (max 999 MB)"
  def error_to_string(:not_accepted), do: "Please select a valid .zip file"
  def error_to_string(:external_client_failure), do: "Something went wrong during upload"
end
