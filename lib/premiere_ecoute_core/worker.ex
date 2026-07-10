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
    {rate_limit, opts} = Keyword.pop(opts, :rate_limit, 1)

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

      @doc "Cancel all worker jobs, optionally filtered by args key/value pairs."
      @spec cancel_all(keyword()) :: {:ok, non_neg_integer()}
      def cancel_all(args \\ []) do
        args
        |> __MODULE__.job_query()
        |> Oban.cancel_all_jobs()
      end

      @doc "Returns the scheduled_at of the next scheduled job, optionally filtered by args key/value pairs."
      @spec next_in?(keyword()) :: DateTime.t() | nil
      def next_in?(args \\ []) do
        args
        |> __MODULE__.job_query()
        |> Ecto.Query.where([j], j.state == "scheduled")
        |> Ecto.Query.order_by([j], asc: j.scheduled_at)
        |> Ecto.Query.select([j], j.scheduled_at)
        |> Ecto.Query.limit(1)
        |> PremiereEcoute.Repo.one(prefix: "oban")
      end

      @doc """
      Builds the base query for this worker's jobs, optionally filtered by args key/value pairs.

      Uses `Oban.Worker.to_string/1` (strips the "Elixir." prefix) to match how Oban stores `j.worker`.
      """
      @spec job_query(keyword()) :: Ecto.Query.t()
      def job_query(args) do
        worker = Oban.Worker.to_string(__MODULE__)

        Enum.reduce(args, Ecto.Query.where(Oban.Job, worker: ^worker), fn {k, v}, q ->
          Ecto.Query.where(q, [j], fragment("?->>? = ?", j.args, ^Atom.to_string(k), ^to_string(v)))
        end)
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
