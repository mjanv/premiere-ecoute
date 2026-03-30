defmodule PremiereEcoute.Wantlists.Wantlist do
  @moduledoc """
  User wantlist — a personal collection of music items to discover.

  Each user has a single default wantlist. Items within the list reference
  discography records (albums, singles, or artists) by foreign key.
  """

  use PremiereEcouteCore.Aggregate,
    root: [items: [:album, :single, :artist]],
    identity: [:user_id]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Wantlists.WantlistItem

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          items: [WantlistItem.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "wantlists" do
    belongs_to :user, User
    has_many :items, WantlistItem, preload_order: [desc: :inserted_at]

    timestamps(type: :utc_datetime)
  end

  @doc "Wantlist changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(wantlist, attrs) do
    wantlist
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end
end
