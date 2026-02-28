defmodule PremiereEcoute.Donations.Services.GoalsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Donations.Goal

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
end
