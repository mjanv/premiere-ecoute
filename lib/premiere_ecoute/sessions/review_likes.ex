defmodule PremiereEcoute.Sessions.ReviewLikes do
  @moduledoc """
  Context for managing likes on reviews.

  Each user can like a review at most once. Toggling removes the like if it exists, creates it otherwise.
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession.ReviewLike

  @doc """
  Toggles a like for a user on a review.

  Returns `{:ok, :liked}` when the like was created, `{:ok, :unliked}` when removed.
  """
  @spec toggle(integer(), User.t()) :: {:ok, :liked} | {:ok, :unliked}
  def toggle(review_id, %User{id: user_id}) do
    case Repo.get_by(ReviewLike, review_id: review_id, user_id: user_id) do
      nil ->
        %ReviewLike{}
        |> ReviewLike.changeset(%{review_id: review_id, user_id: user_id})
        |> Repo.insert!()

        {:ok, :liked}

      like ->
        Repo.delete!(like)
        {:ok, :unliked}
    end
  end

  @doc """
  Returns the number of likes for a review.
  """
  @spec count_for_review(integer()) :: integer()
  def count_for_review(review_id) do
    ReviewLike
    |> where([l], l.review_id == ^review_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns true if the user has liked the given review.
  """
  @spec liked_by?(integer(), integer()) :: boolean()
  def liked_by?(review_id, user_id) do
    Repo.exists?(from l in ReviewLike, where: l.review_id == ^review_id and l.user_id == ^user_id)
  end

  @doc """
  Returns a MapSet of review IDs liked by the user, from a given list of review IDs.
  Efficient for bulk checking on a page with multiple reviews.
  """
  @spec liked_review_ids(list(integer()), integer()) :: MapSet.t()
  def liked_review_ids(review_ids, user_id) do
    ReviewLike
    |> where([l], l.review_id in ^review_ids and l.user_id == ^user_id)
    |> select([l], l.review_id)
    |> Repo.all()
    |> MapSet.new()
  end
end
