defmodule PremiereEcouteWeb.Twitch.HistoryLive do
  @moduledoc """
  Landing page for uploading and viewing Twitch history data.

  This is an unauthenticated page where users can drop a Twitch data export zip file
  to view their chat history information without creating an account.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Twitch

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> allow_upload(:request, accept: ~w(.zip), max_file_size: 999_000_000, max_entries: 1)
    |> assign(:history, nil)
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
    socket
    |> consume_uploaded_entries(:request, fn %{path: path}, _entry ->
      # Parse history without storing to database
      Twitch.History.read(path)
    end)
    |> List.first()
    |> case do
      %Twitch.History{} = history ->
        socket
        |> assign(:history, history)
        |> assign(:upload_error, nil)

      nil ->
        socket
        |> assign(:history, nil)
        |> assign(:upload_error, "Invalid Twitch data export format")
    end
    |> then(fn socket -> {:noreply, socket} end)
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

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, history: nil, upload_error: nil)}
  end

  def error_to_string(:too_large), do: "File is too large (max 999 MB)"
  def error_to_string(:not_accepted), do: "Please select a valid .zip file"
  def error_to_string(:external_client_failure), do: "Something went wrong during upload"

  # AIDEV-NOTE: helper functions for template formatting
  def format_date(datetime) do
    datetime
    |> Timex.format!("{Mshortname} {D}, {YYYY} at {H}:{m}")
  end

  def calculate_duration(start_time, end_time) do
    case Timex.diff(end_time, start_time, :days) do
      days when days >= 1 ->
        "#{days} day#{if days > 1, do: "s", else: ""} of chat history"

      _ ->
        hours = Timex.diff(end_time, start_time, :hours)

        case hours do
          hours when hours >= 1 ->
            "#{hours} hour#{if hours > 1, do: "s", else: ""} of chat history"

          _ ->
            minutes = Timex.diff(end_time, start_time, :minutes)
            "#{minutes} minute#{if minutes > 1, do: "s", else: ""} of chat history"
        end
    end
  end
end
