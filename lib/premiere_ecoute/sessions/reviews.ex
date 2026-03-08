defmodule PremiereEcoute.Sessions.Reviews do
  @moduledoc """
  Context for managing written reviews on listening sessions and albums.

  A review can be linked to a listening session, an album, or both (when written
  in the context of a session retrospective). One review per user per session and
  one review per user per album are enforced.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession.Review
  alias PremiereEcoute.Sessions.ListeningSession.ReviewLike

  @doc """
  Returns all reviews for a session, preloading the associated user, ordered streamer-first then by insertion date.
  """
  @spec list_for_session(integer()) :: [Review.t()]
  def list_for_session(session_id) do
    Review
    |> from(as: :review)
    |> where([r], r.session_id == ^session_id)
    |> order_by([r], [fragment("CASE WHEN ? = 'streamer' THEN 0 ELSE 1 END", r.role), asc: r.inserted_at])
    |> with_likes_count()
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns all reviews for an album, preloading the associated user, ordered by insertion date.
  """
  @spec list_for_album(integer()) :: [Review.t()]
  def list_for_album(album_id) do
    Review
    |> from(as: :review)
    |> where([r], r.album_id == ^album_id)
    |> order_by([r], asc: r.inserted_at)
    |> with_likes_count()
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns a map of %{album_id => count} for the given list of album IDs.
  """
  @spec count_by_album([integer()]) :: %{integer() => integer()}
  def count_by_album([]), do: %{}

  def count_by_album(album_ids) do
    Review
    |> where([r], r.album_id in ^album_ids)
    |> group_by([r], r.album_id)
    |> select([r], {r.album_id, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the review written by a user for a given session, or nil if none exists.
  """
  @spec get_for_user_and_session(integer(), integer()) :: Review.t() | nil
  def get_for_user_and_session(session_id, user_id) do
    Repo.get_by(Review, session_id: session_id, user_id: user_id)
  end

  @doc """
  Returns the review written by a user for a given album, or nil if none exists.
  """
  @spec get_for_user_and_album(integer(), integer()) :: Review.t() | nil
  def get_for_user_and_album(album_id, user_id) do
    Repo.get_by(Review, album_id: album_id, user_id: user_id)
  end

  @doc """
  Creates a new review by a user.

  Pass `session_id:` to link to a session, `album_id:` to link to an album, or both
  (when writing in a session retrospective context). At least one must be provided.
  One review per user per session and one review per user per album are enforced.

  Returns `{:ok, review}` on success or `{:error, changeset}` on failure.
  """
  @spec create(User.t(), map()) :: {:ok, Review.t()} | {:error, Ecto.Changeset.t()}
  def create(%User{id: user_id}, attrs) do
    attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.put("user_id", user_id)

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing review.

  Returns `{:ok, review}` on success or `{:error, changeset}` on failure.
  """
  @spec update(Review.t(), map()) :: {:ok, Review.t()} | {:error, Ecto.Changeset.t()}
  def update(%Review{} = review, attrs) do
    review
    |> Review.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a review, only if it belongs to the given user.

  Returns `{:ok, review}` on success or `{:error, :not_found}` if the review does not belong to the user.
  """
  @spec delete(integer(), User.t()) :: {:ok, Review.t()} | {:error, :not_found}
  def delete(review_id, %User{id: user_id}) do
    case Repo.get_by(Review, id: review_id, user_id: user_id) do
      nil -> {:error, :not_found}
      review -> Repo.delete(review)
    end
  end

  # AIDEV-NOTE: correlated subquery avoids N+1 when loading likes_count alongside reviews
  defp with_likes_count(query) do
    likes_count_subquery =
      ReviewLike
      |> where([l], l.review_id == parent_as(:review).id)
      |> select([l], count(l.id))

    select_merge(query, [r], %{likes_count: subquery(likes_count_subquery)})
  end
end
