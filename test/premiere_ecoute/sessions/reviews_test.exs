defmodule PremiereEcoute.Sessions.ReviewsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Sessions.ListeningSession.Review
  alias PremiereEcoute.Sessions.Reviews

  setup do
    streamer = user_fixture()
    viewer = user_fixture()
    session = session_fixture(%{user_id: streamer.id, status: :stopped})

    {:ok, streamer: streamer, viewer: viewer, session: session}
  end

  describe "list_for_session/1" do
    test "returns empty list when no reviews", %{session: session} do
      assert [] = Reviews.list_for_session(session.id)
    end

    test "returns all reviews for the session ordered by insertion date", %{session: session, streamer: streamer, viewer: viewer} do
      {:ok, _} = Reviews.create(session.id, streamer, %{role: :streamer, content: "Great session"})
      {:ok, _} = Reviews.create(session.id, viewer, %{role: :viewer, content: "Loved it"})

      reviews = Reviews.list_for_session(session.id)

      assert length(reviews) == 2
      assert Enum.all?(reviews, &match?(%Review{user: %{}}, &1))
    end

    test "does not return reviews from other sessions", %{streamer: streamer, session: session} do
      other_session = session_fixture(%{user_id: streamer.id, status: :stopped})
      {:ok, _} = Reviews.create(other_session.id, streamer, %{role: :streamer, content: "Other"})

      assert [] = Reviews.list_for_session(session.id)
    end
  end

  describe "get_for_user/2" do
    test "returns nil when user has no review", %{session: session, viewer: viewer} do
      assert nil == Reviews.get_for_user(session.id, viewer.id)
    end

    test "returns the user's review", %{session: session, viewer: viewer} do
      {:ok, review} = Reviews.create(session.id, viewer, %{role: :viewer, content: "Nice"})

      assert %Review{id: id} = Reviews.get_for_user(session.id, viewer.id)
      assert id == review.id
    end
  end

  describe "create/3" do
    test "creates a review with required fields", %{session: session, streamer: streamer} do
      assert {:ok, %Review{role: :streamer, content: "Great album"}} =
               Reviews.create(session.id, streamer, %{role: :streamer, content: "Great album"})
    end

    test "creates a review with all optional fields", %{session: session, viewer: viewer} do
      attrs = %{
        role: :viewer,
        content: "Fantastic session",
        rating: 4.5,
        like: true,
        watched_before: false,
        watched_on: ~D[2026-03-07],
        tags: ["jazz", "chill"]
      }

      assert {:ok, review} = Reviews.create(session.id, viewer, attrs)
      assert review.rating == 4.5
      assert review.like == true
      assert review.tags == ["jazz", "chill"]
      assert review.watched_on == ~D[2026-03-07]
    end

    test "returns error if role is missing", %{session: session, viewer: viewer} do
      assert {:error, changeset} = Reviews.create(session.id, viewer, %{content: "No role"})
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error if content exceeds 5000 characters", %{session: session, viewer: viewer} do
      long_content = String.duplicate("a", 5001)

      assert {:error, changeset} = Reviews.create(session.id, viewer, %{role: :viewer, content: long_content})
      assert %{content: [_]} = errors_on(changeset)
    end

    test "returns error if rating is out of range", %{session: session, viewer: viewer} do
      assert {:error, changeset} = Reviews.create(session.id, viewer, %{role: :viewer, rating: 5.5})
      assert %{rating: [_]} = errors_on(changeset)
    end

    test "returns error on duplicate review for same user and session", %{session: session, viewer: viewer} do
      {:ok, _} = Reviews.create(session.id, viewer, %{role: :viewer, content: "First"})

      assert {:error, changeset} = Reviews.create(session.id, viewer, %{role: :viewer, content: "Second"})
      assert %{session_id: [_]} = errors_on(changeset)
    end
  end

  describe "update/2" do
    test "updates an existing review", %{session: session, viewer: viewer} do
      {:ok, review} = Reviews.create(session.id, viewer, %{role: :viewer, content: "Initial"})

      assert {:ok, updated} = Reviews.update(review, %{content: "Updated content", rating: 4.0})
      assert updated.content == "Updated content"
      assert updated.rating == 4.0
    end
  end

  describe "delete/2" do
    test "deletes a review belonging to the user", %{session: session, viewer: viewer} do
      {:ok, review} = Reviews.create(session.id, viewer, %{role: :viewer, content: "To delete"})

      assert {:ok, %Review{}} = Reviews.delete(review.id, viewer)
      assert nil == Reviews.get_for_user(session.id, viewer.id)
    end

    test "returns error when review does not belong to user", %{session: session, viewer: viewer, streamer: streamer} do
      {:ok, review} = Reviews.create(session.id, viewer, %{role: :viewer, content: "Mine"})

      assert {:error, :not_found} = Reviews.delete(review.id, streamer)
    end

    test "returns error when review does not exist", %{viewer: viewer} do
      assert {:error, :not_found} = Reviews.delete(999_999, viewer)
    end
  end
end
