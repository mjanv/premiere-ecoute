defmodule PremiereEcoute.DonationsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Donations

  describe "context module delegations" do
    test "delegates get_goal to Goal.get/1" do
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      retrieved_goal = Donations.get_goal(goal.id)
      assert retrieved_goal.id == goal.id
      assert retrieved_goal.title == "Test Goal"
    end

    test "delegates all_goals to Goal.all/1" do
      {:ok, goal1} =
        Donations.create_goal(%{
          title: "Goal 1",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      {:ok, goal2} =
        Donations.create_goal(%{
          title: "Goal 2",
          target_amount: Decimal.new("200"),
          currency: "EUR",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      all_goals = Donations.all_goals()
      assert length(all_goals) >= 2
      assert goal1.id in Enum.map(all_goals, & &1.id)
      assert goal2.id in Enum.map(all_goals, & &1.id)
    end

    test "delegates get_donation to Donation.get/1" do
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      {:ok, donation} =
        Donations.add_donation(goal, %{
          amount: Decimal.new("50"),
          currency: "USD",
          external_id: "txn_123",
          created_at: DateTime.utc_now()
        })

      retrieved_donation = Donations.get_donation(donation.id)
      assert retrieved_donation.id == donation.id
      assert Decimal.equal?(retrieved_donation.amount, Decimal.new("50"))
    end

    test "delegates all_donations to Donation.all/1" do
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      {:ok, donation1} =
        Donations.add_donation(goal, %{
          amount: Decimal.new("50"),
          currency: "USD",
          external_id: "txn_1",
          created_at: DateTime.utc_now()
        })

      {:ok, donation2} =
        Donations.add_donation(goal, %{
          amount: Decimal.new("75"),
          currency: "USD",
          external_id: "txn_2",
          created_at: DateTime.utc_now()
        })

      all_donations = Donations.all_donations()
      assert length(all_donations) >= 2
      assert donation1.id in Enum.map(all_donations, & &1.id)
      assert donation2.id in Enum.map(all_donations, & &1.id)
    end

    test "delegates get_expense to Expense.get/1" do
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      {:ok, expense} =
        Donations.add_expense(goal, %{
          title: "Test Expense",
          category: "hosting",
          amount: Decimal.new("25"),
          currency: "USD",
          incurred_at: DateTime.utc_now()
        })

      retrieved_expense = Donations.get_expense(expense.id)
      assert retrieved_expense.id == expense.id
      assert retrieved_expense.title == "Test Expense"
    end

    test "delegates all_expenses to Expense.all/1" do
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: ~D[2025-01-01],
          end_date: ~D[2025-12-31]
        })

      {:ok, expense1} =
        Donations.add_expense(goal, %{
          title: "Expense 1",
          category: "hosting",
          amount: Decimal.new("25"),
          currency: "USD",
          incurred_at: DateTime.utc_now()
        })

      {:ok, expense2} =
        Donations.add_expense(goal, %{
          title: "Expense 2",
          category: "other",
          amount: Decimal.new("15"),
          currency: "USD",
          incurred_at: DateTime.utc_now()
        })

      all_expenses = Donations.all_expenses()
      assert length(all_expenses) >= 2
      assert expense1.id in Enum.map(all_expenses, & &1.id)
      assert expense2.id in Enum.map(all_expenses, & &1.id)
    end
  end
end
