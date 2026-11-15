defmodule PremiereEcoute.Wrapped.Workers.ScheduleRecaps do
  @moduledoc """
  Enqueues the computation of the Wrapped recaps of eligible viewers.

  Runs daily from the Oban crontab: during the campaign (December 14th to January 31st) it enqueues the viewers who have no recap yet, which is everyone on the first day and the latecomers afterwards. Pass a `"year"` argument to recompute every viewer of that year, or a `"today"` ISO date to run the campaign as of another day.
  """

  use PremiereEcouteCore.Worker, queue: :wrapped, max_attempts: 1

  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Services.ComputeRecap

  @impl true
  def perform(%Oban.Job{args: %{"year" => year}}), do: ComputeRecap.schedule(year)

  def perform(%Oban.Job{args: args}) do
    today = if iso = args["today"], do: Date.from_iso8601!(iso), else: Date.utc_today()

    if year = Recap.campaign_year(today), do: ComputeRecap.schedule_missing(year)

    :ok
  end
end
