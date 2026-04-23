defmodule PremiereEcouteWeb.Collections.CollectionSessionsLive do
  @moduledoc """
  Collection sessions list LiveView.

  Displays the user's collection sessions with origin/destination playlist names,
  selection mode badge, progress, and status.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Collections

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    sessions = Collections.all_sessions_for_user(scope.user)

    socket
    |> assign(:sessions, sessions)
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("navigate", %{"session_id" => session_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/collections/#{session_id}")}
  end

  @impl true
  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    socket
    |> assign(:show_delete_modal, true)
    |> assign(:session_to_delete, String.to_integer(session_id))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("confirm_delete", _params, %{assigns: %{session_to_delete: session_id}} = socket) do
    session = Collections.get_session(session_id)

    socket =
      case Collections.delete_session(session) do
        {:ok, deleted} ->
          socket
          |> assign(:sessions, Enum.reject(socket.assigns.sessions, &(&1.id == deleted.id)))
          |> put_flash(:info, gettext("Collection deleted successfully"))

        {:error, _} ->
          put_flash(socket, :error, gettext("Failed to delete collection"))
      end

    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @spec mode_label(atom()) :: String.t()
  def mode_label(:streamer_choice), do: "Streamer choice"
  def mode_label(:viewer_vote), do: "Viewer vote"
  def mode_label(:duel), do: "Duel"

  @spec mode_class(atom()) :: String.t()
  def mode_class(:streamer_choice), do: "bg-purple-600/20 text-purple-400 border-purple-500/30"
  def mode_class(:viewer_vote), do: "bg-blue-600/20 text-blue-400 border-blue-500/30"
  def mode_class(:duel), do: "bg-amber-600/20 text-amber-400 border-amber-500/30"

  @spec status_class(atom()) :: String.t()
  def status_class(:pending), do: "bg-yellow-600/20 text-yellow-400 border-yellow-500/30"
  def status_class(:active), do: "bg-green-600/20 text-green-400 border-green-500/30"
  def status_class(:completed), do: "bg-gray-600/20 text-gray-400 border-gray-500/30"
end
