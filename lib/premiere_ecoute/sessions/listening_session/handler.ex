defmodule PremiereEcoute.Sessions.ListeningSession.Handler do
  @moduledoc false

  alias PremiereEcoute.Apis.SpotifyApi

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Scores.Report

  use PremiereEcoute.Core.CommandBus.Handler,
    commands: [
      PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession,
      PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession,
      PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
    ],
    events: [
      PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared,
      PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted,
      PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
    ]

  def handle(%PrepareListeningSession{user_id: user_id, album_id: album_id}) do
    with {:ok, album} <- SpotifyApi.impl().get_album(album_id),
         {:ok, album} <- Album.get_or_create(album),
         {:ok, session} <- ListeningSession.create(%{user_id: user_id, album_id: album.id}) do
      {:ok,
       [
         %SessionPrepared{
           session_id: session.id,
           user_id: session.user_id,
           album_id: session.album_id
         }
       ]}
    else
      {:error, _} -> {:error, [%SessionNotPrepared{user_id: user_id}]}
    end
  end

  def handle(%StartListeningSession{session_id: session_id}) do
    with session <- ListeningSession.get(session_id),
         {:ok, session} <- ListeningSession.next_track(session),
         {:ok, session} <- ListeningSession.start(session) do
      {:ok, [%SessionStarted{session_id: session.id}]}
    else
      _ -> {:error, []}
    end
  end

  def handle(%StopListeningSession{session_id: session_id}) do
    with session <- ListeningSession.get(session_id),
         {:ok, _} <- Report.generate(session),
         {:ok, session} <- ListeningSession.stop(session) do
      {:ok, [%SessionStopped{session_id: session.id}]}
    else
      _ -> {:error, []}
    end
  end

  def dispatch(%{session_id: session_id} = event) do
    PremiereEcouteWeb.PubSub.broadcast("session:#{session_id}", event)
  end

  def dispatch(_), do: :ok
end
