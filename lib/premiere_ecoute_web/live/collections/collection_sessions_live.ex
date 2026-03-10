defmodule PremiereEcouteWeb.Collections.CollectionSessionsLive do
  @moduledoc """
  Collection sessions list LiveView.

  Displays the user's collection sessions with origin/destination playlist names,
  selection mode badge, progress, and status.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Collections.CollectionSession

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    sessions = CollectionSession.all_for_user(scope.user)

    socket
    |> assign(:sessions, sessions)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
