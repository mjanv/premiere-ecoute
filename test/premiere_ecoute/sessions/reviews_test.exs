defmodule PremiereEcoute.Sessions.ReviewsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession.Review
  alias PremiereEcoute.Sessions.Reviews

  setup do
    streamer = user_fixture()
    viewer = user_fixture()

    # Persist albums for FK-linked reviews
    {:ok, album} = Album.create(album_fixture(%{album_id: "album-a"}))
    {:ok, album2} = Album.create(album_fixture(%{album_id: "album-b", tracks: unique_tracks("b")}))

    session = session_fixture(%{user_id: streamer.id, status: :stopped, album_id: album.id})

    {:ok, streamer: streamer, viewer: viewer, session: session, album: album, album2: album2}
  end

  # Build tracks with unique track_ids to avoid unique constraint conflicts across albums
  defp unique_tracks(suffix) do
    alias PremiereEcoute.Discography.Album.Track

    [
      %Track{provider: :spotify, track_id: "track001-#{suffix}", name: "Track One", track_number: 1, duration_ms: 210_000},
      %Track{provider: :spotify, track_id: "track002-#{suffix}", name: "Track Two", track_number: 2, duration_ms: 180_000}
    ]
  end

  describe "list_for_session/1" do
    test "returns empty list when no reviews", %{session: session} do
      assert [] = Reviews.list_for_session(session.id)
    end

    test "returns all reviews ordered streamer-first then by insertion date",
         %{session: session, album: album, streamer: streamer, viewer: viewer} do
      {:ok, _} =
        Reviews.create(streamer, %{role: :streamer, content: "Great session", session_id: session.id, album_id: album.id})

      {:ok, _} = Reviews.create(viewer, %{role: :viewer, content: "Loved it", session_id: session.id, album_id: album.id})

      [first, second] = Reviews.list_for_session(session.id)
      assert first.role == :streamer
      assert second.role == :viewer
      assert match?(%Review{user: %{}}, first)
    end

    test "does not return reviews from other sessions", %{streamer: streamer, session: session, album: album} do
      other_session = session_fixture(%{user_id: streamer.id, status: :stopped, album_id: album.id})
      {:ok, _} = Reviews.create(streamer, %{role: :streamer, content: "Other", session_id: other_session.id, album_id: album.id})

      assert [] = Reviews.list_for_session(session.id)
    end

    test "includes likes_count on each review", %{session: session, album: album, viewer: viewer} do
      {:ok, review} = Reviews.create(viewer, %{role: :viewer, session_id: session.id, album_id: album.id})

      [loaded] = Reviews.list_for_session(session.id)
      assert loaded.id == review.id
      assert loaded.likes_count == 0
    end
  end

  describe "list_for_album/1" do
    test "returns empty list when no reviews", %{album: album} do
      assert [] = Reviews.list_for_album(album.id)
    end

    test "returns all reviews for the album ordered by insertion date",
         %{album: album, streamer: streamer, viewer: viewer} do
      {:ok, _} = Reviews.create(streamer, %{content: "Nice album", album_id: album.id})
      {:ok, _} = Reviews.create(viewer, %{content: "Loved it", album_id: album.id})

      reviews = Reviews.list_for_album(album.id)
      assert length(reviews) == 2
      assert Enum.all?(reviews, &match?(%Review{user: %{}}, &1))
    end

    test "does not return reviews from other albums", %{album: album, album2: album2, viewer: viewer} do
      {:ok, _} = Reviews.create(viewer, %{content: "Other", album_id: album2.id})

      assert [] = Reviews.list_for_album(album.id)
    end

    test "returns session reviews that also link to the album",
         %{session: session, album: album, viewer: viewer} do
      {:ok, _} = Reviews.create(viewer, %{role: :viewer, session_id: session.id, album_id: album.id})

      assert [_] = Reviews.list_for_album(album.id)
    end
  end

  describe "get_for_user_and_session/2" do
    test "returns nil when user has no review", %{session: session, viewer: viewer} do
      assert nil == Reviews.get_for_user_and_session(session.id, viewer.id)
    end

    test "returns the user's session review", %{session: session, album: album, viewer: viewer} do
      {:ok, review} = Reviews.create(viewer, %{role: :viewer, session_id: session.id, album_id: album.id})

      assert %Review{id: id} = Reviews.get_for_user_and_session(session.id, viewer.id)
      assert id == review.id
    end
  end

  describe "get_for_user_and_album/2" do
    test "returns nil when user has no review", %{album: album, viewer: viewer} do
      assert nil == Reviews.get_for_user_and_album(album.id, viewer.id)
    end

    test "returns the user's album review", %{album: album, viewer: viewer} do
      {:ok, review} = Reviews.create(viewer, %{content: "Nice", album_id: album.id})

      assert %Review{id: id} = Reviews.get_for_user_and_album(album.id, viewer.id)
      assert id == review.id
    end

    test "returns a session review that also links to the album",
         %{session: session, album: album, viewer: viewer} do
      {:ok, review} = Reviews.create(viewer, %{role: :viewer, session_id: session.id, album_id: album.id})

      assert %Review{id: id} = Reviews.get_for_user_and_album(album.id, viewer.id)
      assert id == review.id
    end
  end

  describe "create/2" do
    test "creates a session review with role", %{session: session, album: album, streamer: streamer} do
      assert {:ok, %Review{role: :streamer, content: "Great album"}} =
               Reviews.create(streamer, %{role: :streamer, content: "Great album", session_id: session.id, album_id: album.id})
    end

    test "creates an album-only review without role", %{album: album, viewer: viewer} do
      assert {:ok, %Review{role: nil, content: "Standalone review"}} =
               Reviews.create(viewer, %{content: "Standalone review", album_id: album.id})
    end

    test "creates a review linked to both session and album", %{session: session, album: album, viewer: viewer} do
      assert {:ok, review} =
               Reviews.create(viewer, %{role: :viewer, session_id: session.id, album_id: album.id})

      assert review.session_id == session.id
      assert review.album_id == album.id
    end

    test "creates a review with all optional fields", %{session: session, album: album, viewer: viewer} do
      attrs = %{
        role: :viewer,
        content: "Fantastic session",
        rating: 4.5,
        like: true,
        watched_before: false,
        watched_on: ~D[2026-03-07],
        tags: ["jazz", "chill"],
        session_id: session.id,
        album_id: album.id
      }

      assert {:ok, review} = Reviews.create(viewer, attrs)
      assert review.rating == 4.5
      assert review.like == true
      assert review.tags == ["jazz", "chill"]
      assert review.watched_on == ~D[2026-03-07]
    end

    test "returns error when neither session_id nor album_id is given", %{viewer: viewer} do
      assert {:error, changeset} = Reviews.create(viewer, %{role: :viewer, content: "Orphan"})
      assert %{base: [_]} = errors_on(changeset)
    end

    test "returns error if content exceeds 5000 characters", %{session: session, viewer: viewer} do
      long_content = String.duplicate("a", 5001)

      assert {:error, changeset} =
               Reviews.create(viewer, %{role: :viewer, content: long_content, session_id: session.id})

      assert %{content: [_]} = errors_on(changeset)
    end

    test "returns error if rating is out of range", %{session: session, viewer: viewer} do
      assert {:error, changeset} =
               Reviews.create(viewer, %{role: :viewer, rating: 5.5, session_id: session.id})

      assert %{rating: [_]} = errors_on(changeset)
    end

    test "returns error on duplicate review for same user and session", %{session: session, album: album, viewer: viewer} do
      {:ok, _} = Reviews.create(viewer, %{role: :viewer, content: "First", session_id: session.id, album_id: album.id})

      assert {:error, changeset} =
               Reviews.create(viewer, %{role: :viewer, content: "Second", session_id: session.id})

      assert %{session_id: [_]} = errors_on(changeset)
    end

    test "returns error on duplicate review for same user and album", %{album: album, viewer: viewer} do
      {:ok, _} = Reviews.create(viewer, %{content: "First", album_id: album.id})

      assert {:error, changeset} = Reviews.create(viewer, %{content: "Second", album_id: album.id})
      assert %{album_id: [_]} = errors_on(changeset)
    end
  end

  describe "update/2" do
    test "updates an existing review", %{session: session, viewer: viewer} do
      {:ok, review} = Reviews.create(viewer, %{role: :viewer, content: "Initial", session_id: session.id})

      assert {:ok, updated} = Reviews.update(review, %{content: "Updated content", rating: 4.0})
      assert updated.content == "Updated content"
      assert updated.rating == 4.0
    end
  end

  describe "delete/2" do
    test "deletes a review belonging to the user", %{session: session, viewer: viewer} do
      {:ok, review} = Reviews.create(viewer, %{role: :viewer, content: "To delete", session_id: session.id})

      assert {:ok, %Review{}} = Reviews.delete(review.id, viewer)
      assert nil == Reviews.get_for_user_and_session(session.id, viewer.id)
    end

    test "returns error when review does not belong to user", %{session: session, viewer: viewer, streamer: streamer} do
      {:ok, review} = Reviews.create(viewer, %{role: :viewer, content: "Mine", session_id: session.id})

      assert {:error, :not_found} = Reviews.delete(review.id, streamer)
    end

    test "returns error when review does not exist", %{viewer: viewer} do
      assert {:error, :not_found} = Reviews.delete(999_999, viewer)
    end
  end
end
