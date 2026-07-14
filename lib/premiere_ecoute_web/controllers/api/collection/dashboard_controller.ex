defmodule PremiereEcouteWeb.Api.Collection.DashboardController do
  @moduledoc """
  API controller for streamer collection session control.

  Exposes collection session lifecycle commands for programmatic clients (e.g. StreamDeck).
  All actions operate on the authenticated user's current pending or active session.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.CloseVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.CompleteCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.DecideTrack
  alias PremiereEcoute.Collections.CollectionSession.Commands.OpenVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.StartCollectionSession
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteWeb.Schemas

  operation(:show,
    summary: "Get active collection session",
    description: "Returns the authenticated streamer's current active collection session.",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer"],
    responses: [
      ok: {"Collection session state", "application/json", Schemas.CollectionSession},
      not_found: {"No active session", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    user = conn.assigns.current_scope.user

    case CollectionSession.get_by(user_id: user.id, status: :active) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "No active collection session"})
      session -> conn |> put_status(:ok) |> json(session_json(session))
    end
  end

  operation(:start,
    summary: "Start collection session",
    description: "Starts the authenticated streamer's pending collection session.",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer"],
    responses: [
      ok: {"Success", "application/json", Schemas.OkResponse},
      not_found: {"No pending session", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Command failed", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec start(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def start(conn, _params) do
    scope = conn.assigns.current_scope

    case CollectionSession.get_by(user_id: scope.user.id, status: :pending) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No pending collection session"})

      session ->
        %StartCollectionSession{session_id: session.id, scope: scope}
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  operation(:open_vote,
    summary: "Open vote window",
    description: "Opens a vote window for the current track(s) in the active collection session.",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer"],
    request_body: {"Vote window options", "application/json", Schemas.OpenVoteRequest, required: true},
    responses: [
      ok: {"Success", "application/json", Schemas.OkResponse},
      not_found: {"No active session", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Command failed", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec open_vote(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def open_vote(conn, params) do
    scope = conn.assigns.current_scope
    user = scope.user

    case CollectionSession.get_by(user_id: user.id, status: :active) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active collection session"})

      session ->
        mode = params["mode"] && String.to_existing_atom(params["mode"])
        duration = params["duration"] || 60
        {track_id, duel_track_id} = current_track_ids(user.twitch.user_id, session, mode)

        %OpenVoteWindow{
          session_id: session.id,
          scope: scope,
          track_id: track_id,
          duel_track_id: duel_track_id,
          selection_mode: mode,
          vote_duration: duration
        }
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  operation(:close_vote,
    summary: "Close vote window",
    description: "Closes the active vote window in the current collection session.",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer"],
    responses: [
      ok: {"Success", "application/json", Schemas.OkResponse},
      not_found: {"No active session", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Command failed", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec close_vote(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def close_vote(conn, _params) do
    scope = conn.assigns.current_scope

    case CollectionSession.get_by(user_id: scope.user.id, status: :active) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active collection session"})

      session ->
        %CloseVoteWindow{session_id: session.id, scope: scope}
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  operation(:decide,
    summary: "Decide current track",
    description: "Records the streamer's decision (kept/rejected/skipped) for the current track.",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer"],
    request_body: {"Decision payload", "application/json", Schemas.DecideRequest, required: true},
    responses: [
      ok: {"Success", "application/json", Schemas.OkResponse},
      not_found: {"No active session", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Command failed or invalid decision", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec decide(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def decide(conn, %{"decision" => raw_decision}) do
    scope = conn.assigns.current_scope
    user = scope.user

    with {:ok, decision} <- parse_decision(raw_decision),
         session when not is_nil(session) <- CollectionSession.get_by(user_id: user.id, status: :active) do
      {track_id, duel_track_id} = current_track_ids(user.twitch.user_id, session, nil)

      %DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: track_id,
        decision: decision,
        duel_track_id: duel_track_id
      }
      |> PremiereEcoute.apply()
      |> command_response(conn)
    else
      {:error, :invalid_decision} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid decision value"})
      nil -> conn |> put_status(:not_found) |> json(%{error: "No active collection session"})
    end
  end

  def decide(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "Missing decision param"})
  end

  operation(:complete,
    summary: "Complete collection session",
    description: "Completes the collection session and syncs kept tracks to the destination playlist.",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer"],
    request_body: {"Completion options", "application/json", Schemas.CompleteRequest, required: false},
    responses: [
      ok: {"Success", "application/json", Schemas.OkResponse},
      not_found: {"No active session", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Command failed", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec complete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def complete(conn, params) do
    scope = conn.assigns.current_scope

    case CollectionSession.get_by(user_id: scope.user.id, status: :active) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active collection session"})

      session ->
        %CompleteCollectionSession{
          session_id: session.id,
          scope: scope,
          remove_kept: Map.get(params, "remove_kept", false) == true,
          remove_rejected: Map.get(params, "remove_rejected", false) == true
        }
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  defp session_json(session) do
    %{
      id: session.id,
      status: session.status,
      current_index: session.current_index,
      kept_count: length(session.kept),
      rejected_count: length(session.rejected),
      skipped_count: length(session.skipped)
    }
  end

  # Resolves current track_id and duel_track_id from cache; falls back to {nil, nil} on cache miss.
  defp current_track_ids(broadcaster_id, session, mode) do
    case Cache.get(:collections, broadcaster_id) do
      {:ok, %{tracks: tracks}} ->
        track = Enum.at(tracks, session.current_index)
        duel = if mode == :duel, do: Enum.at(tracks, session.current_index + 1)
        {track && track.track_id, duel && duel.track_id}

      _ ->
        {nil, nil}
    end
  end

  defp parse_decision(raw) when raw in ["kept", "rejected", "skipped"], do: {:ok, String.to_existing_atom(raw)}
  defp parse_decision(_), do: {:error, :invalid_decision}

  defp command_response({:ok, _session, _events}, conn), do: json(conn, %{ok: true})

  defp command_response({:error, reason}, conn) when is_binary(reason) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
  end

  defp command_response({:error, _}, conn) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "Command failed"})
  end
end
