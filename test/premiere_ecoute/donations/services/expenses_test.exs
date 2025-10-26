defmodule PremiereEcoute.Donations.Services.ExpensesTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Donations.Expense

  describe "add_expense/2" do
    test "adds an expense to a goal" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        title: "Server hosting",
        description: "Monthly server costs",
        category: "hosting",
        amount: Decimal.new("25.00"),
        currency: "USD",
        incurred_at: ~U[2025-01-20 14:30:00Z]
      }

      assert {:ok, %Expense{} = expense} = Donations.add_expense(goal, attrs)
      assert expense.title == "Server hosting"
      assert expense.description == "Monthly server costs"
      assert expense.category == "hosting"
      assert Decimal.equal?(expense.amount, Decimal.new("25.00"))
      assert expense.currency == "USD"
      assert expense.status == :created
      assert expense.goal_id == goal.id
    end

    test "requires title, category, amount, currency, incurred_at" do
      {:ok, goal} = create_test_goal("Test Goal")

      assert {:error, changeset} = Donations.add_expense(goal, %{})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).category
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).currency
    end

    test "validates currency matches goal currency" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        title: "Test Expense",
        category: "hosting",
        amount: Decimal.new("25"),
        currency: "EUR",
        incurred_at: ~U[2025-01-20 14:30:00Z]
      }

      assert {:error, changeset} = Donations.add_expense(goal, attrs)
      assert "must match goal currency (USD)" in errors_on(changeset).currency
    end

    test "validates amount is greater than 0" do
      {:ok, goal} = create_test_goal("Test Goal")

      attrs = %{
        title: "Test Expense",
        category: "hosting",
        amount: Decimal.new("-10"),
        currency: "USD",
        incurred_at: ~U[2025-01-20 14:30:00Z]
      }

      assert {:error, changeset} = Donations.add_expense(goal, attrs)
      assert "must be greater than 0" in errors_on(changeset).amount
    end
  end

  describe "revoke_expense/1" do
    test "updates expense status to refunded" do
      {:ok, goal} = create_test_goal("Test Goal")
      {:ok, expense} = create_test_expense(goal, "Test Expense", Decimal.new("25"))

      assert expense.status == :created

      {:ok, revoked_expense} = Donations.revoke_expense(expense)
      assert revoked_expense.status == :refunded
      assert revoked_expense.id == expense.id
    end

    test "does not delete the expense record" do
      {:ok, goal} = create_test_goal("Test Goal")
      {:ok, expense} = create_test_expense(goal, "Test Expense", Decimal.new("25"))

      {:ok, _} = Donations.revoke_expense(expense)

      persisted_expense = Donations.get_expense(expense.id)
      assert persisted_expense != nil
      assert persisted_expense.status == :refunded
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

  defp create_test_expense(goal, title, amount) do
    Donations.add_expense(goal, %{
      title: title,
      category: "hosting",
      amount: amount,
      currency: "USD",
      incurred_at: DateTime.utc_now()
    })
  end
end
