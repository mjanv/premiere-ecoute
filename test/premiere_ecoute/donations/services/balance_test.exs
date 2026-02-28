defmodule PremiereEcoute.Donations.Services.BalanceTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Donations.Balance

  describe "compute_balance/1" do
    test "computes balance with donations and expenses" do
      {:ok, goal} = create_test_goal("Test Goal")

      {:ok, _} = create_test_donation(goal, "txn_1", Decimal.new("100"))
      {:ok, _} = create_test_donation(goal, "txn_2", Decimal.new("50"))
      {:ok, _} = create_test_expense(goal, "Expense 1", Decimal.new("30"))
      {:ok, _} = create_test_expense(goal, "Expense 2", Decimal.new("20"))

      balance = Donations.compute_balance(goal)

      assert %Balance{} = balance
      assert Decimal.equal?(balance.collected_amount, Decimal.new("150"))
      assert Decimal.equal?(balance.spent_amount, Decimal.new("50"))
      assert Decimal.equal?(balance.remaining_amount, Decimal.new("100"))
      assert balance.progress == 150.0
    end

    test "excludes refunded donations from balance" do
      {:ok, goal} = create_test_goal("Test Goal")

      {:ok, _donation1} = create_test_donation(goal, "txn_1", Decimal.new("100"))
      {:ok, donation2} = create_test_donation(goal, "txn_2", Decimal.new("50"))

      {:ok, _} = Donations.revoke_donation(donation2)

      balance = Donations.compute_balance(goal)

      assert Decimal.equal?(balance.collected_amount, Decimal.new("100"))
    end

    test "excludes refunded expenses from balance" do
      {:ok, goal} = create_test_goal("Test Goal")

      {:ok, _} = create_test_donation(goal, "txn_1", Decimal.new("100"))
      {:ok, _expense1} = create_test_expense(goal, "Expense 1", Decimal.new("30"))
      {:ok, expense2} = create_test_expense(goal, "Expense 2", Decimal.new("20"))

      {:ok, _} = Donations.revoke_expense(expense2)

      balance = Donations.compute_balance(goal)

      assert Decimal.equal?(balance.spent_amount, Decimal.new("30"))
    end

    test "computes balance with no donations or expenses" do
      {:ok, goal} = create_test_goal("Test Goal")

      balance = Donations.compute_balance(goal)

      assert Decimal.equal?(balance.collected_amount, Decimal.new("0"))
      assert Decimal.equal?(balance.spent_amount, Decimal.new("0"))
      assert Decimal.equal?(balance.remaining_amount, Decimal.new("0"))
      assert balance.progress == 0.0
    end

    test "computes correct progress percentage" do
      {:ok, goal} = create_test_goal("Test Goal")

      {:ok, _} = create_test_donation(goal, "txn_1", Decimal.new("50"))

      balance = Donations.compute_balance(goal)

      assert balance.progress == 50.0
    end
  end

  describe "balance in get_current_goal/0" do
    test "returns current goal with computed balance" do
      today = Date.utc_today()
      start_date = Date.add(today, -10)
      end_date = Date.add(today, 10)

      {:ok, goal} =
        Donations.create_goal(%{
          title: "Current Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: start_date,
          end_date: end_date
        })

      {:ok, _} = Donations.enable_goal(goal)
      {:ok, _} = create_test_donation(goal, "txn_1", Decimal.new("75"))

      current_goal = Donations.get_current_goal()

      assert current_goal.id == goal.id
      assert %Balance{} = current_goal.balance
      assert Decimal.equal?(current_goal.balance.collected_amount, Decimal.new("75"))
      assert current_goal.balance.progress == 75.0
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
