defmodule PremiereEcoute.Sessions.ListeningSession.Review do
  @moduledoc false

  use PremiereEcouteCore.Aggregate, root: [:user, :likes], json: [:id]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.ReviewLike

  @type t :: %__MODULE__{}

  schema "reviews" do
    field :role, Ecto.Enum, values: [:streamer, :viewer]

    field :watched_on, :date, default: nil
    field :watched_before, :boolean, default: false

    field :content, :string, default: ""

    field :tags, {:array, :string}, default: []
    field :rating, :float, default: 0.0
    field :like, :boolean

    belongs_to :session, ListeningSession
    belongs_to :user, User

    has_many :likes, ReviewLike

    field :likes_count, :integer, virtual: true, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc "Review changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(review, attrs) do
    review
    |> cast(attrs, [:role, :watched_on, :watched_before, :content, :tags, :rating, :like, :session_id, :user_id])
    |> validate_required([:role, :session_id, :user_id])
    |> validate_inclusion(:role, [:streamer, :viewer])
    |> validate_length(:content, max: 5000)
    |> validate_number(:rating, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0)
    |> unique_constraint([:session_id, :user_id])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:user_id)
  end
end
