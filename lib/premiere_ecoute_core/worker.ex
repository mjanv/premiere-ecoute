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
    {timeout, opts} = Keyword.pop(opts, :timeout, :timer.seconds(300))
    {rate_limit, opts} = Keyword.pop(opts, :rate_limit, :timer.seconds(1))

    quote do
      use Oban.Worker, unquote(opts)

      require Ecto.Query

      @type args() :: map()
      @type one_or_many(t) :: t | [t]
      @type result(t) :: {:ok, t} | {:error, term()}

      @doc "Schedules a job or multiple jobs."
      @spec start(one_or_many(args()), keyword()) :: result(one_or_many(Oban.Job.t()))
      def start(args, opts \\ [])

      def start(args, opts) when is_map(args) do
        args
        |> __MODULE__.new(opts)
        |> Oban.insert()
      end

      def start(args, opts) when is_list(args) do
        args
        |> Enum.map(&__MODULE__.new(&1, opts))
        |> Oban.insert_all()
        |> then(fn jobs -> {:ok, jobs} end)
      end

      @doc "Schedules a job for immediate execution."
      @spec now(one_or_many(args())) :: result(one_or_many(Oban.Job.t()))
      def now(args), do: start(args)

      @doc "Schedules a job to run after a specified number of seconds."
      @spec in_seconds(one_or_many(args()), integer()) :: result(one_or_many(Oban.Job.t()))
      def in_seconds(args, seconds), do: start(args, schedule_in: {seconds, :seconds})

      @doc "Schedules a job to run after a specified number of minutes."
      @spec in_minutes(one_or_many(args()), integer()) :: result(one_or_many(Oban.Job.t()))
      def in_minutes(args, minutes), do: start(args, schedule_in: {minutes, :minutes})

      @doc "Schedules a job to run after a specified number of hours."
      @spec in_hours(one_or_many(args()), integer()) :: result(one_or_many(Oban.Job.t()))
      def in_hours(args, hours), do: start(args, schedule_in: {hours, :hours})

      @doc "Schedules a job to run after a specified number of days."
      @spec in_days(one_or_many(args()), integer()) :: result(one_or_many(Oban.Job.t()))
      def in_days(args, days), do: start(args, schedule_in: {days, :days})

      @doc "Schedules a job to run after a specified number of weeks."
      @spec in_weeks(one_or_many(args()), integer()) :: result(one_or_many(Oban.Job.t()))
      def in_weeks(args, weeks), do: start(args, schedule_in: {weeks, :weeks})

      @doc "Schedules a job to run at a specific datetime."
      @spec at(one_or_many(args()), DateTime.t()) :: result(one_or_many(Oban.Job.t()))
      def at(args, %DateTime{} = at), do: start(args, scheduled_at: DateTime.shift_zone!(at, "Etc/UTC"))

      @doc "Schedule a list of job at specific interval in the future"
      @spec interval([any()], function()) :: :ok
      def interval(args, f) do
        args
        |> Enum.with_index(0)
        |> Enum.each(fn {x, i} -> start(f.(x), schedule_in: i * unquote(rate_limit)) end)
      end

      @doc "Cancel all worker jobs"
      @spec cancel_all :: {:ok, non_neg_integer()}
      def cancel_all do
        worker = Atom.to_string(__MODULE__)

        Oban.Job
        |> Ecto.Query.where(worker: ^worker)
        |> Oban.cancel_all_jobs()
      end

      @doc "Perform the job"
      # @imp Oban.Worker
      # def perform(%Oban.Job{args: args}), do: handle(args)

      @doc "Returns the default job timeout in milliseconds."
      @impl Oban.Worker
      def timeout(_job), do: unquote(timeout)

      # defoverridable handle: 1
    end
  end
end
