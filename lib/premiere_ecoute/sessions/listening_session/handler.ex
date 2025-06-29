defmodule PremiereEcoute.Sessions.ListeningSession.Handler do
  @moduledoc false

  alias PremiereEcoute.Apis.SpotifyApi

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted

  use PremiereEcoute.Core.CommandBus.Handler,
    commands: [PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession],
    events: [PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted]

  def handle(%StartListeningSession{album_id: album_id, streamer_id: streamer_id}) do
    with {:ok, album} <- SpotifyApi.get_album(album_id),
         {:ok, album} <- Album.get_or_create(album),
         {:ok, session} <-
           ListeningSession.create(%{streamer_id: streamer_id, album_id: album.id}) do
      {:ok,
       [
         %SessionStarted{
           session_id: session.id,
           streamer_id: session.streamer_id,
           album_id: session.album_id
         }
       ]}
    else
      {:error, _} -> {:error, [%SessionNotStarted{streamer_id: streamer_id}]}
    end
  end

  def dispatch(%SessionStarted{} = event) do
    PremiereEcouteWeb.PubSub.broadcast("listening_sessions", event)
  end
end
