defmodule PremiereEcouteWeb.Twitch.HistoryLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Twitch

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> allow_upload(:request, accept: ~w(.zip), max_file_size: 999_000_000, max_entries: 1)
    |> assign(:histories, [])
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
  def handle_event("save", _params, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> consume_uploaded_entries(:request, fn %{path: path}, _entry ->
      {:ok, Twitch.create_history(path, current_user)}
    end)
    |> List.first()
    |> case do
      {:ok, _id} ->
        socket
        |> put_flash(:info, "History uploaded")
        |> push_navigate(to: ~p"/")

      {:error, reason} ->
        socket
        |> put_flash(:error, reason)
        |> push_navigate(to: ~p"/")
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
        socket

      entry ->
        socket.assigns.uploads.request
        |> upload_errors(entry)
        |> Enum.reduce(socket, fn error, socket ->
          put_flash(socket, :error, error_to_string(error))
        end)
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{current_user: current_user}} = socket) do
    case Twitch.delete_history(id, current_user) do
      {:ok, _} ->
        socket
        |> put_flash(:info, "History deleted")
        |> push_navigate(to: ~p"/")

      {:error, reason} ->
        socket
        |> put_flash(:error, reason)
        |> push_navigate(to: ~p"/")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  def error_to_string(:external_client_failure), do: "Something went terribly wrong"
end
