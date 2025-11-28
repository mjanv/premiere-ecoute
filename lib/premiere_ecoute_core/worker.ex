defmodule PremiereEcouteCore.Worker do
  @moduledoc """
  Base module for Oban workers.

  Provides convenience functions for scheduling background jobs with various timing options including immediate execution, delays, and specific datetime scheduling.
  """

  @doc """
  Injects Oban worker functionality into the using module.

  Generates job scheduling functions with various timing options (now, in seconds/minutes/hours/days/weeks, at specific datetime) and default timeout configuration.
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    quote do
      use Oban.Worker, unquote(opts)

      @doc "Schedules a job or multiple jobs."
      @spec start(map() | list(map()), keyword()) ::
              {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()} | {:ok, list(Oban.Job.t())} | {:error, term()}
      def start(args, opts \\ [])
      def start(args, opts) when is_map(args), do: Oban.insert(__MODULE__.new(args, opts))
      def start(args, opts) when is_list(args), do: Oban.insert_all(Enum.map(args, &__MODULE__.new(&1, opts)))

      @doc "Schedules a job for immediate execution."
      @spec now(map() | list(map())) :: {:ok, Oban.Job.t()} | {:error, term()}
      def now(args), do: start(args)

      @doc "Schedules a job to run after a specified number of seconds."
      @spec in_seconds(map() | list(map()), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
      def in_seconds(args, seconds), do: start(args, schedule_in: {seconds, :seconds})

      @doc "Schedules a job to run after a specified number of minutes."
      @spec in_minutes(map() | list(map()), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
      def in_minutes(args, minutes), do: start(args, schedule_in: {minutes, :minutes})

      @doc "Schedules a job to run after a specified number of hours."
      @spec in_hours(map() | list(map()), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
      def in_hours(args, hours), do: start(args, schedule_in: {hours, :hours})

      @doc "Schedules a job to run after a specified number of days."
      @spec in_days(map() | list(map()), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
      def in_days(args, days), do: start(args, schedule_in: {days, :days})

      @doc "Schedules a job to run after a specified number of weeks."
      @spec in_weeks(map() | list(map()), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
      def in_weeks(args, weeks), do: start(args, schedule_in: {weeks, :weeks})

      @doc "Schedules a job to run at a specific datetime."
      @spec at(map() | list(map()), DateTime.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
      def at(args, %DateTime{} = at), do: start(args, scheduled_at: DateTime.shift_zone!(at, "Etc/UTC"))

      @doc "Returns the default job timeout in milliseconds."
      @spec timeout(Oban.Job.t()) :: integer()
      @impl Oban.Worker
      def timeout(_job), do: :timer.seconds(300)
    end
  end
end
