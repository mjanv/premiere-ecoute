defmodule PremiereEcoute.Donations.Services.DonationsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Donations.Donation

  describe "add_donation/2" do
    test "adds a donation to a goal" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        amount: Decimal.new("50.00"),
        currency: "USD",
        provider: :buymeacoffee,
        external_id: "txn_123456",
        donor_name: "John Doe",
        created_at: ~U[2025-01-15 10:00:00Z]
      }

      assert {:ok, %Donation{} = donation} = Donations.add_donation(goal, attrs)
      assert Decimal.equal?(donation.amount, Decimal.new("50.00"))
      assert donation.currency == "USD"
      assert donation.provider == :buymeacoffee
      assert donation.status == :created
      assert donation.external_id == "txn_123456"
      assert donation.donor_name == "John Doe"
      assert donation.goal_id == goal.id
    end

    test "requires amount, currency, external_id, created_at" do
      {:ok, goal} = create_test_goal("Test Goal")

      assert {:error, changeset} = Donations.add_donation(goal, %{})
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).currency
      assert "can't be blank" in errors_on(changeset).external_id
    end

    test "validates external_id is unique" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        amount: Decimal.new("50"),
        currency: "USD",
        external_id: "txn_duplicate",
        created_at: ~U[2025-01-15 10:00:00Z]
      }

      {:ok, _} = Donations.add_donation(goal, attrs)
      assert {:error, changeset} = Donations.add_donation(goal, attrs)
      assert "has already been taken" in errors_on(changeset).external_id
    end

    test "validates currency matches goal currency" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        amount: Decimal.new("50"),
        currency: "EUR",
        external_id: "txn_123",
        created_at: ~U[2025-01-15 10:00:00Z]
      }

      assert {:error, changeset} = Donations.add_donation(goal, attrs)
      assert "must match goal currency (USD)" in errors_on(changeset).currency
    end

    test "validates amount is greater than 0" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        amount: Decimal.new("-10"),
        currency: "USD",
        external_id: "txn_123",
        created_at: ~U[2025-01-15 10:00:00Z]
      }

      assert {:error, changeset} = Donations.add_donation(goal, attrs)
      assert "must be greater than 0" in errors_on(changeset).amount
    end
  end

  describe "revoke_donation/1" do
    test "updates donation status to refunded" do
      {:ok, goal} = create_test_goal("Test Goal")
      {:ok, donation} = create_test_donation(goal, "txn_123", Decimal.new("50"))

      assert donation.status == :created

      {:ok, revoked_donation} = Donations.revoke_donation(donation)
      assert revoked_donation.status == :refunded
      assert revoked_donation.id == donation.id
    end

    test "does not delete the donation record" do
      {:ok, goal} = create_test_goal("Test Goal")
      {:ok, donation} = create_test_donation(goal, "txn_123", Decimal.new("50"))

      {:ok, _} = Donations.revoke_donation(donation)

      persisted_donation = Donations.get_donation(donation.id)
      assert persisted_donation != nil
      assert persisted_donation.status == :refunded
    end
  end

  # Helper functions

  defp create_test_goal(title, start_date \\ ~D[2025-01-01], end_date \\ ~D[2025-12-31]) do
    Donations.create_goal(%{
      title: title,
      target_amount: Decimal.new("100"),
      currency: "USD",
      start_date: start_date,
      end_date: end_date
    })
  end

  defp create_test_donation(goal, external_id, amount) do
    Donations.add_donation(goal, %{
      amount: amount,
      currency: "USD",
      external_id: external_id,
      created_at: DateTime.utc_now()
    })
  end
end
