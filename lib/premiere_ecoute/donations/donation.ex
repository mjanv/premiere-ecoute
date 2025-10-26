defmodule PremiereEcoute.Donations.Donation do
  @moduledoc """
  Donation schema representing payments from supporters via BuyMeACoffee.

  Stores donation information including amount, provider, status, and full webhook payload.
  Each donation is linked to a goal and can be revoked (status changed to :refunded).
  """

  use PremiereEcouteCore.Aggregate,
    root: [:goal],
    json: [:id, :amount, :currency, :provider, :status, :external_id, :donor_name, :created_at]

  alias PremiereEcoute.Donations.Goal

  @type t :: %__MODULE__{
          id: integer() | nil,
          amount: Decimal.t(),
          currency: String.t(),
          provider: :buymeacoffee,
          status: :created | :refunded,
          external_id: String.t(),
          donor_name: String.t() | nil,
          payload: map(),
          created_at: DateTime.t(),
          goal_id: integer() | nil,
          goal: Goal.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "donations" do
    field :amount, :decimal
    field :currency, :string
    field :provider, Ecto.Enum, values: [:buymeacoffee], default: :buymeacoffee
    field :status, Ecto.Enum, values: [:created, :refunded], default: :created
    field :external_id, :string
    field :donor_name, :string
    field :payload, :map
    field :created_at, :utc_datetime

    belongs_to :goal, Goal

    timestamps(type: :utc_datetime)
  end

  def changeset(donation, attrs) do
    donation
    |> cast(attrs, [
      :amount,
      :currency,
      :provider,
      :status,
      :external_id,
      :donor_name,
      :payload,
      :created_at,
      :goal_id
    ])
    |> validate_required([
      :amount,
      :currency,
      :provider,
      :status,
      :external_id,
      :created_at
    ])
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency, is: 3)
    |> validate_inclusion(:provider, [:buymeacoffee])
    |> validate_inclusion(:status, [:created, :refunded])
    |> unique_constraint(:external_id)
    |> foreign_key_constraint(:goal_id)
    |> validate_currency_matches_goal()
  end

  # AIDEV-NOTE: Validate currency matches goal currency when goal_id is present
  # This validation ensures direct calls to add_donation/2 have matching currencies
  # create_donation/1 converts currencies before calling add_donation/2, so this won't fail
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
