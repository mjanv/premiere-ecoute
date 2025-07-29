defmodule PremiereEcoute.Core.Worker do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use Oban.Worker, unquote(opts)

      def start(args), do: Oban.insert(__MODULE__.new(args))
      def in_seconds(args, seconds), do: Oban.insert(__MODULE__.new(args, schedule_in: {seconds, :seconds}))
      def in_minutes(args, minutes), do: Oban.insert(__MODULE__.new(args, schedule_in: {minutes, :minutes}))
      def in_hours(args, hours), do: Oban.insert(__MODULE__.new(args, schedule_in: {hours, :hours}))
      def in_days(args, days), do: Oban.insert(__MODULE__.new(args, schedule_in: {days, :days}))
      def in_weeks(args, weeks), do: Oban.insert(__MODULE__.new(args, schedule_in: {weeks, :weeks}))
      def at(args, %DateTime{} = at), do: Oban.insert(__MODULE__.new(args, scheduled_at: DateTime.shift_zone!(at, "Etc/UTC")))

      @impl Oban.Worker
      def timeout(_job), do: :timer.seconds(300)
    end
  end
end
