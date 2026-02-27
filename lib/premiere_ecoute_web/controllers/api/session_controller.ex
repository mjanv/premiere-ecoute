defmodule PremiereEcouteWeb.Api.SessionController do
  @moduledoc """
  API controller for listening session control.

  Exposes session lifecycle and track navigation for programmatic clients (e.g. StreamDeck).
  All actions operate on the authenticated user's current active session.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report

  @doc """
  Returns the authenticated user's current session state.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    user = conn.assigns.current_scope.user

    case Sessions.get_active_session(user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No active session"})

      session ->
        cover_url =
          cond do
            session.album != nil -> session.album.cover_url
            session.playlist != nil -> session.playlist.cover_url
            true -> nil
          end

        current_track_id =
          cond do
            session.current_track != nil -> session.current_track.id
            session.current_playlist_track != nil -> session.current_playlist_track.id
            true -> nil
          end

        viewer_score =
          with id when not is_nil(id) <- current_track_id,
               %Report{track_summaries: summaries} <- Report.get_by(session_id: session.id),
               %{viewer_score: score} <- Enum.find(summaries, fn s -> s.track_id == id end) do
            score
          else
            _ -> nil
          end

        conn
        |> put_status(:ok)
        |> json(%{
          id: session.id,
          status: session.status,
          source: session.source,
          cover_url: cover_url,
          viewer_score: viewer_score
        })
    end
  end

  @doc """
  Starts the user's current session.
  """
  @spec start(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def start(conn, _params) do
    scope = conn.assigns.current_scope

    case Sessions.current_session(scope.user) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active session"})

      session ->
        with {:ok, session, _} <-
               PremiereEcoute.apply(%StartListeningSession{session_id: session.id, source: session.source, scope: scope}),
             {:ok, _session, _} <-
               PremiereEcoute.apply(%SkipNextTrackListeningSession{session_id: session.id, source: session.source, scope: scope}) do
          json(conn, %{ok: true})
        else
          {:error, reason} when is_binary(reason) -> conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Command failed"})
        end
    end
  end

  @doc """
  Stops the user's current session.
  """
  @spec stop(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stop(conn, _params) do
    scope = conn.assigns.current_scope

    case Sessions.current_session(scope.user) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active session"})

      session ->
        %StopListeningSession{session_id: session.id, source: session.source, scope: scope}
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  @doc """
  Skips to the next track in the user's current session.
  """
  @spec next(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def next(conn, _params) do
    scope = conn.assigns.current_scope

    case Sessions.current_session(scope.user) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active session"})

      session ->
        %SkipNextTrackListeningSession{session_id: session.id, source: session.source, scope: scope}
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  @doc """
  Skips to the previous track in the user's current session.
  """
  @spec previous(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def previous(conn, _params) do
    scope = conn.assigns.current_scope

    case Sessions.current_session(scope.user) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active session"})

      session ->
        %SkipPreviousTrackListeningSession{session_id: session.id, source: session.source, scope: scope}
        |> PremiereEcoute.apply()
        |> command_response(conn)
    end
  end

  @doc """
  Submits a vote for the current track (0–10).
  """
  @spec vote(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def vote(conn, %{"rating" => rating}) when rating in 0..10 do
    user = conn.assigns.current_scope.user
    user_id = user.twitch.user_id

    Sessions.publish_message(%MessageSent{
      broadcaster_id: user_id,
      user_id: user_id,
      message: to_string(rating),
      is_streamer: true
    })

    json(conn, %{ok: true, rating: rating})
  end

  def vote(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "rating must be an integer between 0 and 10"})
  end

  defp command_response({:ok, _session, _events}, conn) do
    json(conn, %{ok: true})
  end

  defp command_response({:error, reason}, conn) when is_binary(reason) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
  end

  defp command_response({:error, _}, conn) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "Command failed"})
  end
end
