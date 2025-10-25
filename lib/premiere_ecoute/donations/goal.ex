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

  alias PremiereEcoute.Donations.{Balance, Donation, Expense}

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
end
