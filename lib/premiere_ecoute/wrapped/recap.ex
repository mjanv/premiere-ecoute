defmodule PremiereEcoute.Wrapped.Recap do
  @moduledoc """
  Frozen Wrapped snapshot of a viewer for a year.

  `cards` holds the cards shown to the viewer and on the public replay, as plain JSON: the page only renders them.
  """

  use PremiereEcouteCore.Aggregate,
    identity: [:user_id, :year]

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          year: integer() | nil,
          cards: [map()],
          share_token: String.t() | nil,
          version: integer(),
          computed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "wrapped_recaps" do
    field :year, :integer
    field :cards, {:array, :map}, default: []
    field :share_token, :string
    field :version, :integer, default: 1
    field :computed_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  # Bumped when the set of cards changes: recaps stored with another version are recomputed
  @version 1
  @first_year 2026

  @doc "Version of the set of cards a recap is computed with."
  @spec version() :: integer()
  def version, do: @version

  @doc "Tells whether a Wrapped exists for a year: from 2026 up to the current year."
  @spec year?(integer()) :: boolean()
  def year?(year), do: year in @first_year..Date.utc_today().year

  @doc "Fetches the recap of a user for a year, unless it was computed with an older set of cards."
  @spec current(User.t(), integer()) :: t() | nil
  def current(%User{id: id}, year), do: get_by(user_id: id, year: year, version: @version)

  @doc """
  Year of the running campaign, if any: from December 14th of a year to January 31st of the next one.

  Recaps are generated, ensured and promoted during that period only.
  """
  @spec campaign_year(Date.t()) :: integer() | nil
  def campaign_year(today \\ Date.utc_today()) do
    cond do
      Date.compare(today, Date.new!(today.year, 12, 14)) != :lt -> today.year
      Date.compare(today, Date.new!(today.year, 1, 31)) != :gt -> today.year - 1
      true -> nil
    end
    |> then(&if(&1 && year?(&1), do: &1))
  end

  @doc "Lists the ids of the users with a recap of a year computed with the current set of cards."
  @spec user_ids(integer()) :: [integer()]
  def user_ids(year), do: Repo.all(from(r in __MODULE__, where: r.year == ^year and r.version == ^@version, select: r.user_id))

  @doc "Tells whether a recap is still promoted on the home page: until the end of January following its year."
  @spec promoted?(t(), Date.t()) :: boolean()
  def promoted?(%__MODULE__{year: year}, today \\ Date.utc_today()),
    do: Date.compare(today, Date.new!(year + 1, 1, 31)) != :gt

  @doc "Fetches the latest recap of a user that has cards and was computed with the current set of cards."
  @spec available(User.t()) :: t() | nil
  def available(%User{id: id}) do
    from(r in __MODULE__,
      where: r.user_id == ^id and r.version == ^@version and fragment("cardinality(?) > 0", r.cards),
      order_by: [desc: r.year],
      limit: 1
    )
    |> Repo.one()
  end

  @doc "Fetches a recap from its public share token, unless it was computed with an older set of cards."
  @spec shared(integer(), String.t()) :: t() | nil
  def shared(year, token), do: get_by(year: year, share_token: token, version: @version)

  @doc "Paginates the recaps of a year for the admin, newest first, optionally filtered by username."
  @spec list_for_admin(integer(), String.t(), pos_integer(), pos_integer()) :: Scrivener.Page.t()
  def list_for_admin(year, search \\ "", page_number, page_size) do
    from(r in __MODULE__, join: u in assoc(r, :user), where: r.year == ^year, order_by: [desc: r.computed_at], preload: [user: u])
    |> then(fn query ->
      case String.trim(search) do
        "" -> query
        term -> where(query, [_r, u], ilike(u.username, ^"%#{term}%"))
      end
    end)
    |> Repo.paginate(page: page_number, page_size: page_size)
  end

  @doc "Counts the recaps of a year: all of them, those computed with an older set of cards, and those without any card."
  @spec stats(integer()) :: %{total: integer(), outdated: integer(), empty: integer()}
  def stats(year) do
    from(r in __MODULE__,
      where: r.year == ^year,
      select: %{
        total: count(r.id),
        outdated: count(r.id) |> filter(r.version != ^@version),
        empty: count(r.id) |> filter(fragment("cardinality(?) = 0", r.cards))
      }
    )
    |> Repo.one()
  end

  @doc "Recap changeset. The share token is generated once and kept across recomputations."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(recap, attrs) do
    recap
    |> cast(attrs, [:user_id, :year, :cards, :version, :computed_at])
    |> validate_required([:user_id, :year, :version, :computed_at])
    |> put_share_token()
    |> unique_constraint([:user_id, :year])
    |> unique_constraint(:share_token)
    |> foreign_key_constraint(:user_id)
  end

  defp put_share_token(%Ecto.Changeset{data: %{share_token: nil}} = changeset) do
    put_change(changeset, :share_token, :crypto.strong_rand_bytes(9) |> Base.url_encode64(padding: false))
  end

  defp put_share_token(changeset), do: changeset

  @doc "Inserts the recap of a user for a year, or replaces its cards when it already exists."
  @spec store(integer(), integer(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def store(user_id, year, attrs) do
    (get_by(user_id: user_id, year: year) || %__MODULE__{})
    |> changeset(Map.merge(attrs, %{user_id: user_id, year: year}))
    |> Repo.insert_or_update()
  end
end
