defmodule PremiereEcoute.DonationsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Donations.{Balance, Donation, Expense, Goal}

  describe "create_goal/1" do
    test "creates a goal with valid attributes" do
      attrs = %{
        title: "Server Hosting Fund",
        description: "Raise money for server hosting costs",
        target_amount: Decimal.new("100.00"),
        currency: "USD",
        start_date: ~D[2025-01-01],
        end_date: ~D[2025-12-31]
      }

      assert {:ok, %Goal{} = goal} = Donations.create_goal(attrs)
      assert goal.title == "Server Hosting Fund"
      assert goal.description == "Raise money for server hosting costs"
      assert Decimal.equal?(goal.target_amount, Decimal.new("100.00"))
      assert goal.currency == "USD"
      assert goal.start_date == ~D[2025-01-01]
      assert goal.end_date == ~D[2025-12-31]
      assert goal.active == false
    end

    test "requires title, target_amount, currency, start_date, end_date" do
      assert {:error, changeset} = Donations.create_goal(%{})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).target_amount
      assert "can't be blank" in errors_on(changeset).currency
      assert "can't be blank" in errors_on(changeset).start_date
      assert "can't be blank" in errors_on(changeset).end_date
    end

    test "validates end_date is after start_date" do
      attrs = %{
        title: "Invalid Goal",
        target_amount: Decimal.new("100"),
        currency: "USD",
        start_date: ~D[2025-12-31],
        end_date: ~D[2025-01-01]
      }

      assert {:error, changeset} = Donations.create_goal(attrs)
      assert "must be after start date" in errors_on(changeset).end_date
    end

    test "validates currency is 3 characters" do
      attrs = %{
        title: "Test Goal",
        target_amount: Decimal.new("100"),
        currency: "US",
        start_date: ~D[2025-01-01],
        end_date: ~D[2025-12-31]
      }

      assert {:error, changeset} = Donations.create_goal(attrs)
      assert "should be 3 character(s)" in errors_on(changeset).currency
    end

    test "validates target_amount is greater than 0" do
      attrs = %{
        title: "Test Goal",
        target_amount: Decimal.new("-10"),
        currency: "USD",
        start_date: ~D[2025-01-01],
        end_date: ~D[2025-12-31]
      }

      assert {:error, changeset} = Donations.create_goal(attrs)
      assert "must be greater than 0" in errors_on(changeset).target_amount
    end
  end

  describe "enable_goal/1" do
    test "enables a goal and disables all other goals" do
      {:ok, goal1} = create_test_goal("Goal 1")
      {:ok, goal2} = create_test_goal("Goal 2")
      {:ok, goal3} = create_test_goal("Goal 3")

      {:ok, _} = Donations.enable_goal(goal1)
      {:ok, enabled_goal} = Donations.enable_goal(goal2)

      assert enabled_goal.active == true

      updated_goal1 = Donations.get_goal(goal1.id)
      updated_goal3 = Donations.get_goal(goal3.id)

      assert updated_goal1.active == false
      assert updated_goal3.active == false
    end

    test "only one goal is active at a time" do
      {:ok, goal1} = create_test_goal("Goal 1")
      {:ok, goal2} = create_test_goal("Goal 2")

      {:ok, _} = Donations.enable_goal(goal1)

      active_goals = Donations.all_goals(where: [active: true])
      assert length(active_goals) == 1

      {:ok, _} = Donations.enable_goal(goal2)

      active_goals = Donations.all_goals(where: [active: true])
      assert length(active_goals) == 1
      assert hd(active_goals).id == goal2.id
    end
  end

  describe "disable_goal/1" do
    test "disables an active goal" do
      {:ok, goal} = create_test_goal("Test Goal")
      {:ok, enabled_goal} = Donations.enable_goal(goal)
      assert enabled_goal.active == true

      {:ok, disabled_goal} = Donations.disable_goal(enabled_goal)
      assert disabled_goal.active == false
    end
  end

  describe "get_current_goal/0" do
    test "returns the active goal within the current date range" do
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

      current_goal = Donations.get_current_goal()
      assert current_goal.id == goal.id
    end

    test "returns nil if no active goal in current date range" do
      past_start = Date.add(Date.utc_today(), -30)
      past_end = Date.add(Date.utc_today(), -10)

      {:ok, goal} =
        Donations.create_goal(%{
          title: "Past Goal",
          target_amount: Decimal.new("100"),
          currency: "USD",
          start_date: past_start,
          end_date: past_end
        })

      {:ok, _} = Donations.enable_goal(goal)

      assert Donations.get_current_goal() == nil
    end

    test "returns nil if goal is not active" do
      today = Date.utc_today()
      {:ok, _goal} = create_test_goal("Inactive Goal", Date.add(today, -10), Date.add(today, 10))

      assert Donations.get_current_goal() == nil
    end
  end

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

      {:ok, donation1} = create_test_donation(goal, "txn_1", Decimal.new("100"))
      {:ok, donation2} = create_test_donation(goal, "txn_2", Decimal.new("50"))

      {:ok, _} = Donations.revoke_donation(donation2)

      balance = Donations.compute_balance(goal)

      assert Decimal.equal?(balance.collected_amount, Decimal.new("100"))
    end

    test "excludes refunded expenses from balance" do
      {:ok, goal} = create_test_goal("Test Goal")

      {:ok, _} = create_test_donation(goal, "txn_1", Decimal.new("100"))
      {:ok, expense1} = create_test_expense(goal, "Expense 1", Decimal.new("30"))
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

  describe "get_current_goal_with_balance/0" do
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

      current_goal = Donations.get_current_goal_with_balance()

      assert current_goal.id == goal.id
      assert %Balance{} = current_goal.balance
      assert Decimal.equal?(current_goal.balance.collected_amount, Decimal.new("75"))
      assert current_goal.balance.progress == 75.0
    end

    test "returns nil if no current goal" do
      assert Donations.get_current_goal_with_balance() == nil
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
