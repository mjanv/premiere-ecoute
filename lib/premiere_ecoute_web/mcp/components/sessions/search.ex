defmodule PremiereEcouteWeb.Mcp.Components.Sessions.Search do
  @moduledoc "List past stopped sessions for the authenticated user (admin/streamer only)"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Sessions.ListeningSession

  schema do
    field :limit, :integer
  end

  @impl true
  def execute(_params, %{assigns: %{current_user: %{role: role}}} = frame)
      when role not in [:admin, :streamer] do
    {:reply, Response.error(Response.tool(), "Forbidden: admin or streamer role required."), frame}
  end

  def execute(params, %{assigns: %{current_user: user}} = frame) do
    limit = min(Map.get(params, :limit) || 10, 50)

    sessions =
      ListeningSession.all(
        where: [user_id: user.id, status: :stopped],
        order_by: [desc: :started_at],
        limit: limit
      )
      |> Enum.map(&format/1)

    {:reply, Response.json(Response.tool(), %{sessions: sessions}), frame}
  end

  defp format(session) do
    %{
      id: session.id,
      source: session.source,
      title: title(session),
      started_at: session.started_at,
      ended_at: session.ended_at
    }
  end

  defp title(%{source: :free, name: name}), do: name || "Free session"
  defp title(%{album: %{name: name}}), do: name
  defp title(%{playlist: %{title: title}}), do: title
  defp title(%{single: %{name: name}}), do: name
  defp title(_), do: nil
end
