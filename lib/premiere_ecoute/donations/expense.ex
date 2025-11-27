defmodule PremiereEcoute.Donations.Expense do
  @moduledoc """
  Expense schema representing spending tracked against fundraising goals.

  Provides transparency by tracking how collected donations are spent.
  Each expense is linked to a goal and can be revoked (status changed to :refunded).
  """

  use PremiereEcouteCore.Aggregate,
    root: [:goal],
    json: [:id, :title, :description, :category, :amount, :currency, :incurred_at, :status]

  alias PremiereEcoute.Donations.Goal

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t(),
          description: String.t() | nil,
          category: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          incurred_at: DateTime.t(),
          status: :created | :paid | :refunded,
          goal_id: integer() | nil,
          goal: Goal.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "expenses" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :amount, :decimal
    field :currency, :string
    field :incurred_at, :utc_datetime
    field :status, Ecto.Enum, values: [:created, :paid, :refunded], default: :created

    belongs_to :goal, Goal

    timestamps(type: :utc_datetime)
  end

  @doc """
  Expense changeset.

  Validates expense data including amount, currency, and ensures currency matches the associated goal's currency.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(expense, attrs) do
    expense
    |> cast(attrs, [
      :title,
      :description,
      :category,
      :amount,
      :currency,
      :incurred_at,
      :status,
      :goal_id
    ])
    |> validate_required([
      :title,
      :category,
      :amount,
      :currency,
      :incurred_at,
      :status,
      :goal_id
    ])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:category, min: 1, max: 100)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency, is: 3)
    |> validate_inclusion(:status, [:created, :paid, :refunded])
    |> foreign_key_constraint(:goal_id)
    |> validate_currency_matches_goal()
  end

  defp validate_currency_matches_goal(changeset) do
    goal_id = get_field(changeset, :goal_id)
    currency = get_field(changeset, :currency)

    if goal_id && currency do
      case Goal.get(goal_id) do
        nil ->
          changeset

        goal ->
          if goal.currency == currency do
            changeset
          else
            add_error(
              changeset,
              :currency,
              "must match goal currency (#{goal.currency})"
            )
          end
      end
    else
      changeset
    end
  end
end
