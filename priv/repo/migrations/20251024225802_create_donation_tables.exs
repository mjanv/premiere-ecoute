defmodule PremiereEcoute.Repo.Migrations.CreateDonationTables do
  use Ecto.Migration

  def change do
    # AIDEV-NOTE: Goals table stores fundraising campaigns with date ranges and target amounts
    create table(:goals) do
      add :title, :string, null: false
      add :description, :text
      add :target_amount, :decimal, precision: 15, scale: 2, null: false
      add :currency, :string, null: false
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :active, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:goals, :currency_must_be_valid,
             check: "length(currency) = 3"
           )

    create constraint(:goals, :end_date_after_start_date,
             check: "end_date > start_date"
           )

    create index(:goals, [:active])
    create index(:goals, [:start_date, :end_date])

    # AIDEV-NOTE: Donations table stores payments from BuyMeACoffee with full webhook payload
    create table(:donations) do
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :currency, :string, null: false
      add :provider, :string, null: false
      add :status, :string, null: false
      add :external_id, :string, null: false
      add :donor_name, :string
      add :payload, :map, null: false, default: %{}
      add :created_at, :utc_datetime, null: false

      add :goal_id, references(:goals, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:donations, :provider_must_be_valid,
             check: "provider IN ('buymeacoffee')"
           )

    create constraint(:donations, :status_must_be_valid,
             check: "status IN ('created', 'refunded')"
           )

    create constraint(:donations, :currency_must_be_valid,
             check: "length(currency) = 3"
           )

    create unique_index(:donations, [:external_id])
    create index(:donations, [:goal_id])
    create index(:donations, [:status])
    create index(:donations, [:created_at])
    execute("CREATE INDEX donation_payloads ON donations USING GIN(payload)")

    # AIDEV-NOTE: Expenses table tracks spending against goals for transparency
    create table(:expenses) do
      add :title, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :currency, :string, null: false
      add :incurred_at, :utc_datetime, null: false
      add :status, :string, null: false

      add :goal_id, references(:goals, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:expenses, :status_must_be_valid,
             check: "status IN ('created', 'paid', 'refunded')"
           )

    create constraint(:expenses, :currency_must_be_valid,
             check: "length(currency) = 3"
           )

    create index(:expenses, [:goal_id])
    create index(:expenses, [:status])
    create index(:expenses, [:incurred_at])
    create index(:expenses, [:category])
  end
end
