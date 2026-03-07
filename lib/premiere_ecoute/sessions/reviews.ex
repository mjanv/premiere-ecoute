defmodule PremiereEcoute.Sessions.Reviews do
  @moduledoc """
  Context for managing written reviews on listening sessions.

  Both streamers and viewers can write one review per session after it ends.
  Reviews are visible to all authorized users of the session's retrospective page.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession.Review

  @doc """
  Returns all reviews for a session, preloading the associated user, ordered by insertion date.
  """
  @spec list_for_session(integer()) :: [Review.t()]
  def list_for_session(session_id) do
    Review
    |> where([r], r.session_id == ^session_id)
    |> order_by([r], asc: r.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns the review written by a user for a given session, or nil if none exists.
  """
  @spec get_for_user(integer(), integer()) :: Review.t() | nil
  def get_for_user(session_id, user_id) do
    Repo.get_by(Review, session_id: session_id, user_id: user_id)
  end

  @doc """
  Creates a new review for a session by a user.

  Returns `{:ok, review}` on success or `{:error, changeset}` on failure.
  One review per user per session is enforced.
  """
  @spec create(integer(), User.t(), map()) :: {:ok, Review.t()} | {:error, Ecto.Changeset.t()}
  def create(session_id, %User{id: user_id}, attrs) do
    attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.merge(%{"session_id" => session_id, "user_id" => user_id})

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
end
