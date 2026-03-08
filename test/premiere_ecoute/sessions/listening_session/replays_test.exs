defmodule PremiereEcoute.Sessions.ListeningSession.ReplaysTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    user = user_fixture(%{role: :streamer})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
    {:ok, %{session: session}}
  end

  describe "update_replays/2" do
    test "saves a list of replay links", %{session: session} do
      replays = [
        %{"label" => "YouTube VOD", "url" => "https://youtube.com/watch?v=abc"},
        %{"label" => "Twitch VOD", "url" => "https://twitch.tv/videos/123"}
      ]

      {:ok, updated} = ListeningSession.update_replays(session, replays)

      assert updated.replays == replays
    end

    test "persists replays to the database", %{session: session} do
      replays = [%{"label" => "YouTube", "url" => "https://youtube.com/watch?v=abc"}]

      {:ok, _} = ListeningSession.update_replays(session, replays)

      reloaded = ListeningSession.get(session.id)
      assert reloaded.replays == replays
    end

    test "replaces existing replays", %{session: session} do
      {:ok, session} =
        ListeningSession.update_replays(session, [
          %{"label" => "Old VOD", "url" => "https://youtube.com/watch?v=old"}
        ])

      new_replays = [%{"label" => "New VOD", "url" => "https://youtube.com/watch?v=new"}]
      {:ok, updated} = ListeningSession.update_replays(session, new_replays)

      assert updated.replays == new_replays
    end

    test "strips entries with blank URL", %{session: session} do
      replays = [
        %{"label" => "Good", "url" => "https://youtube.com/watch?v=abc"},
        %{"label" => "Empty", "url" => ""},
        %{"label" => "Whitespace", "url" => "   "}
      ]

      {:ok, updated} = ListeningSession.update_replays(session, replays)

      assert updated.replays == [%{"label" => "Good", "url" => "https://youtube.com/watch?v=abc"}]
    end

    test "strips entries with nil URL", %{session: session} do
      replays = [
        %{"label" => "Good", "url" => "https://youtube.com/watch?v=abc"},
        %{"label" => "No URL", "url" => nil}
      ]

      {:ok, updated} = ListeningSession.update_replays(session, replays)

      assert updated.replays == [%{"label" => "Good", "url" => "https://youtube.com/watch?v=abc"}]
    end

    test "saves empty list when all entries are blank", %{session: session} do
      {:ok, updated} = ListeningSession.update_replays(session, [%{"label" => "", "url" => ""}])

      assert updated.replays == []
    end

    test "saves empty list", %{session: session} do
      {:ok, session} =
        ListeningSession.update_replays(session, [
          %{"label" => "VOD", "url" => "https://youtube.com/watch?v=abc"}
        ])

      {:ok, updated} = ListeningSession.update_replays(session, [])

      assert updated.replays == []
    end

    test "label is optional", %{session: session} do
      replays = [%{"label" => "", "url" => "https://youtube.com/watch?v=abc"}]

      {:ok, updated} = ListeningSession.update_replays(session, replays)

      assert updated.replays == replays
    end
  end
end
