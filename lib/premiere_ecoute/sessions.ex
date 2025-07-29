defmodule PremiereEcoute.Sessions do
  @moduledoc false

  alias PremiereEcoute.Sessions.Discography
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective

  # Listening session
  defdelegate create_session(attrs), to: ListeningSession, as: :create
  defdelegate start_session(session), to: ListeningSession, as: :start
  defdelegate stop_session(session), to: ListeningSession, as: :stop
  defdelegate next_track(session), to: ListeningSession
  defdelegate previous_track(session), to: ListeningSession
  defdelegate active_sessions(user), to: ListeningSession

  # Discography
  defdelegate create_album(album), to: Discography.Album, as: :create
  defdelegate create_playlist(playlist), to: Discography.Playlist, as: :create

  # Retrospective
  defdelegate get_albums_by_period(user_id, period, opts \\ %{}), to: Retrospective
  defdelegate get_album_session_details(session_id), to: Retrospective
end
