defmodule PremiereEcoute.Sessions.ListeningSession.Review do
  @moduledoc false

  use PremiereEcouteCore.Aggregate, root: [:user, :likes], json: [:id]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album
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
    belongs_to :album, Album
    belongs_to :user, User

    has_many :likes, ReviewLike

    field :likes_count, :integer, virtual: true, default: 0
    # AIDEV-NOTE: virtual field to round-trip raw tag input string through the form without losing it on re-render
    field :tags_input, :string, virtual: true, default: ""

    timestamps(type: :utc_datetime)
  end

  @doc "Review changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :role,
      :watched_on,
      :watched_before,
      :content,
      :tags,
      :tags_input,
      :rating,
      :like,
      :session_id,
      :album_id,
      :user_id
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:role, [:streamer, :viewer])
    |> validate_length(:content, max: 5000)
    |> validate_number(:rating, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0)
    |> validate_at_least_one_target()
    |> unique_constraint([:session_id, :user_id], name: :reviews_session_id_user_id_index)
    |> unique_constraint([:album_id, :user_id], name: :reviews_album_id_user_id_index)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:album_id)
    |> foreign_key_constraint(:user_id)
  end

  # AIDEV-NOTE: mirrors DB check constraint — at least one of session_id/album_id must be set
  defp validate_at_least_one_target(changeset) do
    session_id = get_field(changeset, :session_id)
    album_id = get_field(changeset, :album_id)

    if is_nil(session_id) and is_nil(album_id) do
      add_error(changeset, :base, "must be linked to a session or an album")
    else
      changeset
    end
  end
end
