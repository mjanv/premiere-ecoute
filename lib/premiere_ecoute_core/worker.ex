defmodule PremiereEcouteCore.Worker do
  @moduledoc """
  Base module for Oban workers.

  Provides convenience functions for scheduling background jobs with various timing options including immediate execution, delays, and specific datetime scheduling.
  """

  defmacro __using__(opts) do
    quote do
      use Oban.Worker, unquote(opts)

      def start(args, opts \\ [])
      def start(args, opts) when is_map(args), do: Oban.insert(__MODULE__.new(args, opts))
      def start(args, opts) when is_list(args), do: Oban.insert_all(Enum.map(args, &__MODULE__.new(&1, opts)))

      def now(args), do: start(args)
      def in_seconds(args, seconds), do: start(args, schedule_in: {seconds, :seconds})
      def in_minutes(args, minutes), do: start(args, schedule_in: {minutes, :minutes})
      def in_hours(args, hours), do: start(args, schedule_in: {hours, :hours})
      def in_days(args, days), do: start(args, schedule_in: {days, :days})
      def in_weeks(args, weeks), do: start(args, schedule_in: {weeks, :weeks})
      def at(args, %DateTime{} = at), do: start(args, scheduled_at: DateTime.shift_zone!(at, "Etc/UTC"))

      @impl Oban.Worker
      def timeout(_job), do: :timer.seconds(300)
    end
  end
end
