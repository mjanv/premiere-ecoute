defmodule PremiereEcouteWeb.Playlists.Automations.IndexLive do
  @moduledoc "Index page — lists all automations for the current user."

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Automations

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    automations = Automations.list_automations(user)

    socket
    |> assign(:automations, automations)
    |> then(fn socket -> {:ok, socket} end)
  end
end
