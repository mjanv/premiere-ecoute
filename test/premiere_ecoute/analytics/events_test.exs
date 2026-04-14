defmodule PremiereEcoute.Analytics.EventsTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Analytics.Events
  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Events.AccountDeleted
  alias PremiereEcoute.Events.Store

  # AIDEV-NOTE: async: false — inserts go directly into event_store.events
  # which is outside the sandboxed Ecto transaction. Each test uses a unique
  # event_type string (scoped to a UUID marker) so rows from parallel or
  # prior tests never pollute counts. No cleanup needed: the event store's
  # DELETE trigger prevents row removal, and type-scoped queries are isolated.

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Inserts a row directly into event_store.events with a controlled created_at.
  # We bypass EventStore entirely because:
  #   1. The store sets created_at = NOW() with no override.
  #   2. The events table has immutable UPDATE and DELETE triggers.
  # The event_type is scoped to `marker` so each test is fully isolated.
  defp seed_event(event_type, created_at, extra_data \\ %{}) do
    # Pass data as a map so Postgrex serializes it as jsonb correctly.
    # Passing a JSON-encoded string inserts a jsonb string, not an object,
    # which makes data->>'key' return nil.
    # UUIDs must be passed as 16-byte binaries for uuid columns.
    data = Map.merge(%{"id" => UUID.uuid4()}, extra_data)

    Repo.insert_all(
      "events",
      [
        %{
          event_id: Ecto.UUID.dump!(UUID.uuid4()),
          event_type: event_type,
          data: data,
          metadata: %{},
          created_at: created_at
        }
      ],
      prefix: "event_store"
    )
  end

  # Returns a unique event type string scoped to the current test.
  # Using this instead of a real module prevents cross-test count pollution.
  defp event_type(marker, suffix \\ "Created"), do: "Test.#{marker}.#{suffix}"

  # Truncates microseconds from a DateTime for readable assertions.
  defp truncate_dt(dt), do: DateTime.truncate(dt, :second)

  # ---------------------------------------------------------------------------
  # aggregate/3 – basic counting
  # ---------------------------------------------------------------------------

  describe "aggregate/3 counts by time unit" do
    test "returns empty list when no events exist" do
      marker = UUID.uuid4()
      result = Events.aggregate(event_type(marker), :month)
      assert result == []
    end

    test "counts events by month" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-01-10 12:00:00Z])
      seed_event(et, ~U[2026-01-20 08:00:00Z])
      seed_event(et, ~U[2026-02-05 09:00:00Z])

      result = Events.aggregate(et, :month)

      jan = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-01-01 00:00:00Z]))
      feb = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-02-01 00:00:00Z]))

      assert jan.count == 2
      assert feb.count == 1
    end

    test "counts events by day" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-03-01 08:00:00Z])
      seed_event(et, ~U[2026-03-01 20:00:00Z])
      seed_event(et, ~U[2026-03-02 10:00:00Z])

      result = Events.aggregate(et, :day)

      day1 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-01 00:00:00Z]))
      day2 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-02 00:00:00Z]))

      assert day1.count == 2
      assert day2.count == 1
    end

    test "counts events by hour" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-03-01 08:00:00Z])
      seed_event(et, ~U[2026-03-01 08:45:00Z])
      seed_event(et, ~U[2026-03-01 09:10:00Z])

      result = Events.aggregate(et, :hour)

      h8 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-01 08:00:00Z]))
      h9 = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-03-01 09:00:00Z]))

      assert h8.count == 2
      assert h9.count == 1
    end

    test "only counts events matching the given type" do
      marker = UUID.uuid4()
      et_a = event_type(marker, "Created")
      et_b = event_type(marker, "Deleted")

      seed_event(et_a, ~U[2026-01-01 00:00:00Z])
      seed_event(et_b, ~U[2026-01-01 00:00:00Z])

      result = Events.aggregate(et_a, :month)

      assert length(result) == 1
      assert hd(result).count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :from / :to filters
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :from and :to options" do
    test "filters events after :from" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-01-01 00:00:00Z])
      seed_event(et, ~U[2026-02-01 00:00:00Z])
      seed_event(et, ~U[2026-03-01 00:00:00Z])

      result = Events.aggregate(et, :month, from: ~U[2026-02-01 00:00:00Z])
      periods = Enum.map(result, &truncate_dt(&1.period))

      refute ~U[2026-01-01 00:00:00Z] in periods
      assert ~U[2026-02-01 00:00:00Z] in periods
      assert ~U[2026-03-01 00:00:00Z] in periods
    end

    test "filters events before :to" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-01-01 00:00:00Z])
      seed_event(et, ~U[2026-02-01 00:00:00Z])
      seed_event(et, ~U[2026-03-01 00:00:00Z])

      result = Events.aggregate(et, :month, to: ~U[2026-02-28 23:59:59Z])
      periods = Enum.map(result, &truncate_dt(&1.period))

      assert ~U[2026-01-01 00:00:00Z] in periods
      assert ~U[2026-02-01 00:00:00Z] in periods
      refute ~U[2026-03-01 00:00:00Z] in periods
    end

    test "filters events between :from and :to" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-01-01 00:00:00Z])
      seed_event(et, ~U[2026-02-01 00:00:00Z])
      seed_event(et, ~U[2026-03-01 00:00:00Z])

      result =
        Events.aggregate(et, :month,
          from: ~U[2026-02-01 00:00:00Z],
          to: ~U[2026-02-28 23:59:59Z]
        )

      assert length(result) == 1
      assert truncate_dt(hd(result).period) == ~U[2026-02-01 00:00:00Z]
      assert hd(result).count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :fields grouping
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :fields option" do
    test "groups by a single data field" do
      marker = UUID.uuid4()
      et = event_type(marker, "Associated")

      seed_event(et, ~U[2026-01-01 00:00:00Z], %{"provider" => "twitch"})
      seed_event(et, ~U[2026-01-15 00:00:00Z], %{"provider" => "twitch"})
      seed_event(et, ~U[2026-01-20 00:00:00Z], %{"provider" => "spotify"})

      result = Events.aggregate(et, :month, fields: [:provider])

      twitch = Enum.find(result, &(&1[:provider] == "twitch"))
      spotify = Enum.find(result, &(&1[:provider] == "spotify"))

      assert twitch.count == 2
      assert spotify.count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :filters option
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :filters option" do
    test "restricts to rows matching a field value" do
      marker = UUID.uuid4()
      et = event_type(marker, "Associated")

      seed_event(et, ~U[2026-01-01 00:00:00Z], %{"provider" => "twitch"})
      seed_event(et, ~U[2026-01-15 00:00:00Z], %{"provider" => "twitch"})
      seed_event(et, ~U[2026-01-20 00:00:00Z], %{"provider" => "spotify"})

      result = Events.aggregate(et, :month, filters: %{provider: "twitch"})

      assert length(result) == 1
      assert hd(result).count == 2
    end

    test "filters and groups can be combined" do
      marker = UUID.uuid4()
      et = event_type(marker, "Associated")

      seed_event(et, ~U[2026-01-01 00:00:00Z], %{"provider" => "twitch", "region" => "eu"})
      seed_event(et, ~U[2026-01-10 00:00:00Z], %{"provider" => "twitch", "region" => "us"})
      seed_event(et, ~U[2026-02-01 00:00:00Z], %{"provider" => "twitch", "region" => "eu"})
      seed_event(et, ~U[2026-02-01 00:00:00Z], %{"provider" => "spotify", "region" => "eu"})

      result =
        Events.aggregate(et, :month,
          fields: [:region],
          filters: %{provider: "twitch"}
        )

      # spotify row excluded; twitch rows grouped by month × region
      assert Enum.all?(result, fn row -> row[:region] != nil end)

      jan_eu = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-01-01 00:00:00Z] and &1[:region] == "eu"))
      jan_us = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-01-01 00:00:00Z] and &1[:region] == "us"))
      feb_eu = Enum.find(result, &(truncate_dt(&1.period) == ~U[2026-02-01 00:00:00Z] and &1[:region] == "eu"))

      assert jan_eu.count == 1
      assert jan_us.count == 1
      assert feb_eu.count == 1
    end

    test "multiple filters are ANDed together" do
      marker = UUID.uuid4()
      et = event_type(marker, "Associated")

      seed_event(et, ~U[2026-01-01 00:00:00Z], %{"provider" => "twitch", "region" => "eu"})
      seed_event(et, ~U[2026-01-10 00:00:00Z], %{"provider" => "twitch", "region" => "us"})
      seed_event(et, ~U[2026-01-20 00:00:00Z], %{"provider" => "spotify", "region" => "eu"})

      result = Events.aggregate(et, :month, filters: %{provider: "twitch", region: "eu"})

      assert length(result) == 1
      assert hd(result).count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :fill_gaps option
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :fill_gaps option" do
    test "fills missing periods with count 0" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-01-01 00:00:00Z])
      # February intentionally empty
      seed_event(et, ~U[2026-03-01 00:00:00Z])

      result =
        Events.aggregate(et, :month,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-03-31 23:59:59Z],
          fill_gaps: true
        )

      assert length(result) == 3

      counts = Enum.map(result, & &1.count)
      assert counts == [1, 0, 1]
    end

    test "all periods present produces same result as without fill_gaps" do
      marker = UUID.uuid4()
      et = event_type(marker)

      seed_event(et, ~U[2026-01-15 00:00:00Z])
      seed_event(et, ~U[2026-02-10 00:00:00Z])

      result =
        Events.aggregate(et, :month,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-02-28 23:59:59Z],
          fill_gaps: true
        )

      assert length(result) == 2
      assert Enum.all?(result, &(&1.count > 0))
    end

    test "raises when :from is missing" do
      assert_raise ArgumentError, ~r/:fill_gaps requires/, fn ->
        Events.aggregate("Test.Event", :month, fill_gaps: true, to: ~U[2026-03-01 00:00:00Z])
      end
    end

    test "raises when :to is missing" do
      assert_raise ArgumentError, ~r/:fill_gaps requires/, fn ->
        Events.aggregate("Test.Event", :month, fill_gaps: true, from: ~U[2026-01-01 00:00:00Z])
      end
    end

    test "raises when combined with :fields" do
      assert_raise ArgumentError, ~r/:fill_gaps is not supported/, fn ->
        Events.aggregate("Test.Event", :month,
          fill_gaps: true,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-03-31 00:00:00Z],
          fields: [:provider]
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – :stream scoping
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with :stream option" do
    # Stream tests use Store.append/2 so stream_events/streams rows are created.
    # Store.append with stream: "foo" creates singular stream "foo-<id>" and
    # plural stream "foos". We query by the plural stream uuid to scope a
    # collection, or by the singular to scope one entity.
    # created_at is NOW() — we only assert counts, not specific period values.

    test "restricts to events in a single stream" do
      id_a = UUID.uuid4()
      id_b = UUID.uuid4()

      Store.append(%AccountCreated{id: id_a}, stream: "analytics-test-account")
      Store.append(%AccountCreated{id: id_a}, stream: "analytics-test-account")
      Store.append(%AccountCreated{id: id_b}, stream: "analytics-test-account")

      et = "Elixir.PremiereEcoute.Events.AccountCreated"

      result_a = Events.aggregate(et, :month, stream: "analytics-test-account-#{id_a}")
      result_b = Events.aggregate(et, :month, stream: "analytics-test-account-#{id_b}")

      assert Enum.sum(Enum.map(result_a, & &1.count)) == 2
      assert Enum.sum(Enum.map(result_b, & &1.count)) == 1
    end

    test "accepts a list of streams" do
      id_a = UUID.uuid4()
      id_b = UUID.uuid4()
      id_c = UUID.uuid4()

      Store.append(%AccountCreated{id: id_a}, stream: "analytics-test-account")
      Store.append(%AccountCreated{id: id_b}, stream: "analytics-test-account")
      Store.append(%AccountCreated{id: id_c}, stream: "analytics-test-account")

      et = "Elixir.PremiereEcoute.Events.AccountCreated"

      result =
        Events.aggregate(et, :month, stream: ["analytics-test-account-#{id_a}", "analytics-test-account-#{id_b}"])

      assert Enum.sum(Enum.map(result, & &1.count)) == 2
    end

    test "nil event type counts all event types in a stream" do
      id = UUID.uuid4()

      Store.append(%AccountCreated{id: id}, stream: "analytics-test-account")
      Store.append(%AccountDeleted{id: id}, stream: "analytics-test-account")
      Store.append(%AccountCreated{id: id}, stream: "analytics-test-account")

      result = Events.aggregate(nil, :month, stream: "analytics-test-account-#{id}")

      assert Enum.sum(Enum.map(result, & &1.count)) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # aggregate/3 – invalid unit
  # ---------------------------------------------------------------------------

  describe "aggregate/3 with invalid unit" do
    test "raises ArgumentError for unknown time unit" do
      assert_raise ArgumentError, ~r/invalid unit :minute/, fn ->
        Events.aggregate("Test.SomeEvent", :minute)
      end
    end
  end
end
