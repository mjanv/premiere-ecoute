defmodule PremiereEcouteWeb.Mcp.Components.Sessions.Active do
  @moduledoc "Active listening session state for the authenticated user (admin/streamer only)"

  use Hermes.Server.Component,
    type: :resource,
    uri: "session://me/active",
    mime_type: "application/json"

  alias Hermes.Server.Response
  alias PremiereEcoute.Sessions

  @impl true
  def read(_params, %{assigns: %{current_user: %{role: role}}} = frame)
      when role not in [:admin, :streamer] do
    {:reply, Response.json(Response.resource(), %{error: "forbidden", reason: "admin or streamer role required"}), frame}
  end

  def read(_params, %{assigns: %{current_user: user}} = frame) do
    payload =
      case Sessions.get_active_session(user) do
        nil -> %{active: false}
        session -> %{active: true, session: format(session)}
      end

    {:reply, Response.json(Response.resource(), payload), frame}
  end

  defp format(session) do
    %{
      id: session.id,
      status: session.status,
      source: session.source,
      vote_mode: session.vote_mode,
      started_at: session.started_at,
      title: title(session),
      current_track: format_track(session),
      vote_options: session.vote_options,
      options: session.options
    }
  end

  defp title(%{source: :free, name: name}), do: name || "Free session"
  defp title(%{album: %{name: name}}), do: name
  defp title(%{playlist: %{title: title}}), do: title
  defp title(%{single: %{name: name}}), do: name
  defp title(_), do: nil

  defp format_track(%{source: :album, current_track: %{} = track}),
    do: %{name: track.name, number: track.track_number}

  defp format_track(%{source: :playlist, current_playlist_track: %{} = track}),
    do: %{name: track.name, number: track.position}

  defp format_track(%{source: :track, single: %{} = single}),
    do: %{name: single.name, number: nil}

  defp format_track(%{source: :free, track_markers: markers}) when is_list(markers) do
    case Enum.max_by(markers, & &1.started_at, DateTime, fn -> nil end) do
      nil -> nil
      marker -> %{name: marker.track_name, number: marker.track_number}
    end
  end

  defp format_track(_), do: nil
end
