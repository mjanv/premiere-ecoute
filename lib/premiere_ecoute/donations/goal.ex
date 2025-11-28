defmodule PremiereEcoute.Donations.Goal do
  @moduledoc """
  Goal schema representing fundraising campaigns with target amounts and date ranges.

  A goal tracks donations and expenses over a specified period. Only one goal
  can be active at a time. The balance is stored as a JSONB map in the database
  but is represented as a Balance struct in the application layer through conversions
  in the Donations context module.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:donations, :expenses],
    json: [:id, :title, :description, :target_amount, :currency, :start_date, :end_date, :active]

  import Ecto.Query

  alias PremiereEcoute.Donations.{Balance, Donation, Expense}
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t(),
          description: String.t() | nil,
          target_amount: Decimal.t(),
          currency: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          active: boolean(),
          balance: Balance.t() | nil,
          donations: [Donation.t()] | Ecto.Association.NotLoaded.t(),
          expenses: [Expense.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "goals" do
    field :title, :string
    field :description, :string
    field :target_amount, :decimal
    field :currency, :string
    field :start_date, :date
    field :end_date, :date
    field :active, :boolean, default: false
    embeds_one :balance, Balance, on_replace: :update

    has_many :donations, Donation
    has_many :expenses, Expense

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates changeset for goal with validation on dates and amounts.

  Validates title, target_amount, currency (3-char ISO code), start_date and end_date with end after start, and optionally casts embedded balance.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :title,
      :description,
      :target_amount,
      :currency,
      :start_date,
      :end_date,
      :active
    ])
    |> cast_embed(:balance, with: &Balance.changeset/2, required: false, force: true)
    |> validate_required([
      :title,
      :target_amount,
      :currency,
      :start_date,
      :end_date
    ])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_number(:target_amount, greater_than: 0)
    |> validate_length(:currency, is: 3)
    |> validate_date_range()
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(end_date, start_date) != :gt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end

  @doc """
  Returns the most recent created donation for a goal using a SQL query.

  This is more efficient than loading all donations and filtering in memory.

  ## Examples

      iex> Goal.last_donation(goal)
      %Donation{}

      iex> Goal.last_donation(goal_id)
      %Donation{}

      iex> Goal.last_donation(goal_with_no_donations)
      nil
  """
  @spec last_donation(t() | integer()) :: Donation.t() | nil
  def last_donation(%__MODULE__{id: goal_id}), do: last_donation(goal_id)

  def last_donation(goal_id) when is_integer(goal_id) do
    from(d in Donation,
      where: d.goal_id == ^goal_id,
      where: d.status == :created,
      order_by: [desc: d.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end
end
