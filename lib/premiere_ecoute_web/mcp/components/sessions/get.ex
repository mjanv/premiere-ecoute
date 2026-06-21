defmodule PremiereEcouteWeb.Mcp.Components.Sessions.Get do
  @moduledoc "Fetch a stopped session with its track markers and scores (admin/streamer, own sessions only)"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession

  schema do
    field :session_id, :integer, required: true
  end

  @impl true
  def execute(_params, %{assigns: %{current_user: %{role: role}}} = frame)
      when role not in [:admin, :streamer] do
    {:reply, Response.error(Response.tool(), "Forbidden: admin or streamer role required."), frame}
  end

  def execute(%{session_id: session_id}, %{assigns: %{current_user: user}} = frame) do
    case ListeningSession.get_by(id: session_id, user_id: user.id) do
      nil ->
        {:reply, Response.error(Response.tool(), "Session not found."), frame}

      %ListeningSession{status: status} when status != :stopped ->
        {:reply, Response.error(Response.tool(), "Session is not stopped yet."), frame}

      session ->
        {:reply, Response.json(Response.tool(), build_payload(session)), frame}
    end
  end

  defp build_payload(session) do
    detail = fetch_detail(session)

    %{
      id: session.id,
      source: session.source,
      status: session.status,
      vote_mode: session.vote_mode,
      started_at: session.started_at,
      ended_at: session.ended_at,
      title: title(session),
      track_markers: format_markers(session.track_markers),
      scores: format_scores(detail)
    }
  end

  defp fetch_detail(%{source: :album, id: id}), do: Sessions.get_album_session_details(id)
  defp fetch_detail(%{source: :track, id: id}), do: Sessions.get_single_session_details(id)
  defp fetch_detail(%{source: :playlist, id: id}), do: Sessions.get_playlist_session_details(id)
  defp fetch_detail(_), do: nil

  defp format_markers(markers) when is_list(markers) do
    Enum.map(markers, fn m ->
      %{
        track_id: m.track_id,
        track_number: m.track_number,
        track_name: m.track_name,
        started_at: m.started_at
      }
    end)
  end

  defp format_markers(_), do: []

  defp format_scores({:ok, %{session: %{report: report}}}) when not is_nil(report) do
    %{
      session_summary: report.session_summary,
      track_summaries: report.track_summaries
    }
  end

  defp format_scores(_), do: nil

  defp title(%{source: :free, name: name}), do: name || "Free session"
  defp title(%{album: %{name: name}}), do: name
  defp title(%{playlist: %{title: title}}), do: title
  defp title(%{single: %{name: name}}), do: name
  defp title(_), do: nil
end
