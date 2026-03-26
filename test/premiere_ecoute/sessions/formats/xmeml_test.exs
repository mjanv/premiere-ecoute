defmodule PremiereEcoute.Sessions.Formats.XmemlTest do
  use PremiereEcoute.DataCase, async: true
  
  alias PremiereEcoute.Sessions.Formats.Xmeml
  
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  
  setup do
    user = user_fixture(%{role: :streamer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

    {:ok, %{session: session}}
  end

  
  describe "build/2" do
    test "?", %{session: session} do
      
      {:ok, session} = ListeningSession.start(session)
      {:ok, session} = ListeningSession.next_track(session)
      {:ok, _marker} = ListeningSession.add_track_marker(session)
      {:ok, _marker} = ListeningSession.add_speech_marker(session, 5000, 8500, "hello")
      
      assert Xmeml.build(session, []) == session
    end
  end
end