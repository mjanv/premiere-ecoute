defmodule PremiereEcoute.Sessions.ListeningSession.SharePathTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    user = user_fixture(%{role: :streamer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, playlist} = Playlist.create(playlist_fixture(%{tracks: []}))
    {:ok, single} = Single.create(single_fixture())

    {:ok, user: user, album: album, playlist: playlist, single: single}
  end

  describe "share_path/1 - album mode" do
    test "returns a slug-token string for an album session", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      assert is_binary(path)
      assert String.contains?(path, session.share_token)
      assert path =~ ~r/^[a-z0-9-]+-[A-Za-z0-9_-]+$/
    end

    test "includes the slugified album name", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      # album_fixture name is "Sample Album" → slug "sample-album"
      assert String.starts_with?(path, "sample-album-")
    end
  end

  describe "share_path/1 - playlist mode" do
    test "returns a slug-token string for a playlist session", %{user: user, playlist: playlist} do
      {:ok, session} = ListeningSession.create(%{source: :playlist, user_id: user.id, playlist_id: playlist.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      assert is_binary(path)
      assert String.contains?(path, session.share_token)
    end

    test "includes the slugified playlist title", %{user: user, playlist: playlist} do
      {:ok, session} = ListeningSession.create(%{source: :playlist, user_id: user.id, playlist_id: playlist.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      # playlist_fixture title is "FLONFLON MUSIC FRIDAY" → slug "flonflon-music-friday"
      assert String.starts_with?(path, "flonflon-music-friday-")
    end
  end

  describe "share_path/1 - single (track) mode" do
    test "returns a slug-token string for a single/track session", %{user: user, single: single} do
      {:ok, session} = ListeningSession.create(%{source: :track, user_id: user.id, single_id: single.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      assert is_binary(path)
      assert String.contains?(path, session.share_token)
    end

    test "includes the slugified track name", %{user: user, single: single} do
      {:ok, session} = ListeningSession.create(%{source: :track, user_id: user.id, single_id: single.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      # single_fixture name is "Sample Track" → slug "sample-track"
      assert String.starts_with?(path, "sample-track-")
    end
  end

  describe "share_path/1 - free mode" do
    test "returns a slug-token string for a named free session", %{user: user} do
      {:ok, session} = ListeningSession.create(%{source: :free, user_id: user.id, name: "My Free Session"})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      assert is_binary(path)
      assert String.contains?(path, session.share_token)
      assert String.starts_with?(path, "my-free-session-")
    end

    test "falls back to 'free-session' slug when no name is set", %{user: user} do
      {:ok, session} = ListeningSession.create(%{source: :free, user_id: user.id})
      session = ListeningSession.get(session.id)

      path = ListeningSession.share_path(session)

      assert is_binary(path)
      assert String.contains?(path, session.share_token)
      assert String.starts_with?(path, "free-session-")
    end
  end

  describe "share_token generation" do
    test "share_token is generated automatically on create", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})

      assert is_binary(session.share_token)
      assert String.length(session.share_token) > 0
    end

    test "two sessions have distinct share tokens", %{user: user, album: album} do
      {:ok, s1} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})
      {:ok, s2} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})

      assert s1.share_token != s2.share_token
    end

    test "get_by_share_token/1 fetches the correct session", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{source: :album, user_id: user.id, album_id: album.id})

      found = ListeningSession.get_by_share_token(session.share_token)

      assert found.id == session.id
    end
  end
end
