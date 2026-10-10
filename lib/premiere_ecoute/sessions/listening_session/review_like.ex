defmodule PremiereEcoute.Sessions.ListeningSession.ReviewLike do
  @moduledoc false

  use PremiereEcouteCore.Aggregate.Object

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Sessions.ListeningSession.Review

  @type t :: %__MODULE__{
          id: integer() | nil,
          review_id: integer() | nil,
          user_id: integer() | nil
        }

  schema "review_likes" do
    belongs_to :review, Review
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a like changeset, one like per user and review.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:review_id, :user_id])
    |> validate_required([:review_id, :user_id])
    |> unique_constraint([:review_id, :user_id])
    |> foreign_key_constraint(:review_id)
    |> foreign_key_constraint(:user_id)
  end
end
