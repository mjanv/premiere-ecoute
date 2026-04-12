defmodule PremiereEcoute.Analytics.AggregatesTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.AccountsFixtures
  alias PremiereEcoute.Analytics.Aggregates
  alias PremiereEcoute.Notifications.Notification

  # We use Notification as the test aggregate because:
  #   - Only FK is user_id (easy to create a real user)
  #   - Has a `type` string column — good for grouping tests
  #   - inserted_at can be set directly via Repo.insert_all

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Insert notifications directly, bypassing the changeset so we can set
  # inserted_at to arbitrary past datetimes for deterministic period tests.
  defp seed_notification(user_id, inserted_at, type \\ "test_event") do
    Repo.insert_all(
      "user_notifications",
      [%{user_id: user_id, type: type, data: %{}, inserted_at: inserted_at}]
    )
  end

  defp truncate_dt(dt), do: DateTime.truncate(dt, :second)

  # ---------------------------------------------------------------------------
  # aggregate/3 – basic counting
  # ---------------------------------------------------------------------------

  describe "aggregate/3 counts by time unit" do
    test "returns empty list when no rows exist" do
      # Use a user with no notifications to get an isolated empty result
      user = AccountsFixtures.unconfirmed_user_fixture()
      result = Aggregates.aggregate(Notification, :month, filters: [user_id: user.id])
      assert result == []
    end

    test "counts rows by month" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-10 12:00:00Z])
      seed_notification(user.id, ~U[2026-01-20 08:00:00Z])
      seed_notification(user.id, ~U[2026-02-05 09:00:00Z])

      result = Aggregates.aggregate(Notification, :month, filters: [user_id: user.id])

      jan = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-01-01 00:00:00Z]))
      feb = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-02-01 00:00:00Z]))

      assert jan.count == 2
      assert feb.count == 1
    end

    test "counts rows by day" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-03-01 08:00:00Z])
      seed_notification(user.id, ~U[2026-03-01 20:00:00Z])
      seed_notification(user.id, ~U[2026-03-02 10:00:00Z])

      result = Aggregates.aggregate(Notification, :day, filters: [user_id: user.id])

      day1 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-01 00:00:00Z]))
      day2 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-02 00:00:00Z]))

      assert day1.count == 2
      assert day2.count == 1
    end

    test "counts rows by hour" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-03-01 08:00:00Z])
      seed_notification(user.id, ~U[2026-03-01 08:45:00Z])
      seed_notification(user.id, ~U[2026-03-01 09:10:00Z])

      result = Aggregates.aggregate(Notification, :hour, filters: [user_id: user.id])

      h8 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-01 08:00:00Z]))
      h9 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-01 09:00:00Z]))

      assert h8.count == 2
      assert h9.count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :from / :to filters
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :from and :to options" do
    test "filters rows after :from" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z])
      seed_notification(user.id, ~U[2026-02-01 00:00:00Z])
      seed_notification(user.id, ~U[2026-03-01 00:00:00Z])

      result =
        Aggregates.aggregate(Notification, :month,
          from: ~U[2026-02-01 00:00:00Z],
          filters: [user_id: user.id]
        )

      periods = Enum.map(result, &truncate_dt(&1.period))

      refute ~U[2026-01-01 00:00:00Z] in periods
      assert ~U[2026-02-01 00:00:00Z] in periods
      assert ~U[2026-03-01 00:00:00Z] in periods
    end

    test "filters rows before :to" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z])
      seed_notification(user.id, ~U[2026-02-01 00:00:00Z])
      seed_notification(user.id, ~U[2026-03-01 00:00:00Z])

      result =
        Aggregates.aggregate(Notification, :month,
          to: ~U[2026-02-28 23:59:59Z],
          filters: [user_id: user.id]
        )

      periods = Enum.map(result, &truncate_dt(&1.period))

      assert ~U[2026-01-01 00:00:00Z] in periods
      assert ~U[2026-02-01 00:00:00Z] in periods
      refute ~U[2026-03-01 00:00:00Z] in periods
    end

    test "filters rows between :from and :to" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z])
      seed_notification(user.id, ~U[2026-02-01 00:00:00Z])
      seed_notification(user.id, ~U[2026-03-01 00:00:00Z])

      result =
        Aggregates.aggregate(Notification, :month,
          from: ~U[2026-02-01 00:00:00Z],
          to: ~U[2026-02-28 23:59:59Z],
          filters: [user_id: user.id]
        )

      assert length(result) == 1
      assert truncate_dt(hd(result).period) == ~U[2026-02-01 00:00:00Z]
      assert hd(result).count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :field grouping
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :field option" do
    test "groups by a schema column" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z], "account_created")
      seed_notification(user.id, ~U[2026-01-15 00:00:00Z], "account_created")
      seed_notification(user.id, ~U[2026-01-20 00:00:00Z], "track_liked")

      result =
        Aggregates.aggregate(Notification, :month,
          field: :type,
          filters: [user_id: user.id]
        )

      created = Enum.find(result, &(&1[:type] == "account_created"))
      liked = Enum.find(result, &(&1[:type] == "track_liked"))

      assert created.count == 2
      assert liked.count == 1
    end

    test "field key is the column atom, not :field_value" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z], "ping")

      result =
        Aggregates.aggregate(Notification, :month,
          field: :type,
          filters: [user_id: user.id]
        )

      assert [row] = result
      assert Map.has_key?(row, :type)
      refute Map.has_key?(row, :field_value)
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :filters option
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :filters option" do
    test "restricts to rows matching a column value" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z], "account_created")
      seed_notification(user.id, ~U[2026-01-15 00:00:00Z], "account_created")
      seed_notification(user.id, ~U[2026-01-20 00:00:00Z], "track_liked")

      result =
        Aggregates.aggregate(Notification, :month, filters: [user_id: user.id, type: "account_created"])

      assert length(result) == 1
      assert hd(result).count == 2
    end

    test "multiple filters are ANDed together" do
      user_a = AccountsFixtures.unconfirmed_user_fixture()
      user_b = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user_a.id, ~U[2026-01-01 00:00:00Z], "ping")
      seed_notification(user_b.id, ~U[2026-01-01 00:00:00Z], "ping")

      result = Aggregates.aggregate(Notification, :month, filters: [user_id: user_a.id, type: "ping"])

      assert length(result) == 1
      assert hd(result).count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :fill_gaps option
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :fill_gaps option" do
    test "fills missing periods with count 0" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-01 00:00:00Z])
      # February intentionally empty
      seed_notification(user.id, ~U[2026-03-01 00:00:00Z])

      result =
        Aggregates.aggregate(Notification, :month,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-03-31 23:59:59Z],
          fill_gaps: true,
          filters: [user_id: user.id]
        )

      assert length(result) == 3
      assert Enum.map(result, & &1.count) == [1, 0, 1]
    end

    test "all periods present produces same result as without fill_gaps" do
      user = AccountsFixtures.unconfirmed_user_fixture()

      seed_notification(user.id, ~U[2026-01-15 00:00:00Z])
      seed_notification(user.id, ~U[2026-02-10 00:00:00Z])

      result =
        Aggregates.aggregate(Notification, :month,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-02-28 23:59:59Z],
          fill_gaps: true,
          filters: [user_id: user.id]
        )

      assert length(result) == 2
      assert Enum.all?(result, &(&1.count > 0))
    end

    test "raises when :from is missing" do
      assert_raise ArgumentError, ~r/:fill_gaps requires/, fn ->
        Aggregates.aggregate(Notification, :month, fill_gaps: true, to: ~U[2026-03-01 00:00:00Z])
      end
    end

    test "raises when :to is missing" do
      assert_raise ArgumentError, ~r/:fill_gaps requires/, fn ->
        Aggregates.aggregate(Notification, :month, fill_gaps: true, from: ~U[2026-01-01 00:00:00Z])
      end
    end

    test "raises when combined with :field" do
      assert_raise ArgumentError, ~r/:fill_gaps is not supported/, fn ->
        Aggregates.aggregate(Notification, :month,
          fill_gaps: true,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-03-31 00:00:00Z],
          field: :type
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – invalid unit
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with invalid unit" do
    test "raises ArgumentError for unknown time unit" do
      assert_raise ArgumentError, ~r/invalid unit :minute/, fn ->
        Aggregates.aggregate(Notification, :minute)
      end
    end
  end
end
