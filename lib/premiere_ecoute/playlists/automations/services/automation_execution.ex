defmodule PremiereEcoute.Playlists.Automations.Services.AutomationExecution do
  @moduledoc """
  Executes an automation's steps sequentially, accumulating context.

  Step results are accumulated in memory and written in a single DB update on
  completion or first failure. Remaining steps after a failure are marked
  `:skipped`. Dispatches an `AutomationFailure` notification on failure.

  The caller (AutomationRunWorker) always returns `:ok` — failures are domain
  outcomes recorded in automation_runs, not Oban job errors.
  """

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Notifications
  alias PremiereEcoute.Notifications.Types.AutomationFailure
  alias PremiereEcoute.Notifications.Types.AutomationSuccess
  alias PremiereEcoute.Playlists.Automations.ActionRegistry
  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.AutomationRun
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Repo

  @doc "Runs all steps of an automation, writes a run record, returns `:ok`."
  @spec run(Automation.t(), integer()) :: :ok
  def run(%Automation{} = automation, job_id) do
    user = Repo.preload(Repo.get!(User, automation.user_id), [:spotify, :twitch])

    scope =
      user
      |> Scope.for_user()
      |> Accounts.maybe_renew_token(:spotify)
      |> Accounts.maybe_renew_token(:twitch)

    {:ok, run} =
      AutomationRun.insert(%{
        automation_id: automation.id,
        oban_job_id: job_id,
        status: :running,
        trigger: :scheduled,
        started_at: DateTime.utc_now(:second)
      })

    PubSub.broadcast("automation:#{automation.id}", {:run_created, run})

    {status, steps} =
      try do
        execute_steps(automation.steps, scope)
      rescue
        e -> {:failed, [%{"error" => Exception.message(e), "status" => "failed"}]}
      end

    {:ok, updated_run} =
      AutomationRun.update(run, %{
        status: status,
        steps: steps,
        finished_at: DateTime.utc_now(:second)
      })

    PubSub.broadcast("automation:#{automation.id}", {:run_updated, updated_run})

    notification =
      if status == :failed do
        %AutomationFailure{automation_id: automation.id, automation_name: automation.name, run_id: run.id}
      else
        %AutomationSuccess{automation_id: automation.id, automation_name: automation.name, run_id: run.id}
      end

    Notifications.dispatch(user, notification)

    :ok
  end

  # AIDEV-NOTE: fold over steps; first failure stops execution and marks rest as :skipped
  defp execute_steps(steps, scope) do
    {status, step_results, _context} =
      Enum.reduce(steps, {:running, [], %{}}, fn step, {status, results, context} ->
        if status == :running do
          execute_step(step, context, scope, results)
        else
          skipped = step_result(step, :skipped, %{}, nil)
          {:failed, results ++ [skipped], context}
        end
      end)

    final_status = if status == :running, do: :completed, else: :failed
    {final_status, step_results}
  end

  defp execute_step(step, context, scope, results) do
    started_at = DateTime.utc_now(:second)

    case ActionRegistry.get(step["action_type"]) do
      {:ok, module} ->
        case module.execute(step["config"] || %{}, context, scope) do
          {:ok, output} ->
            result = step_result(step, :completed, output, nil, started_at)
            {:running, results ++ [result], Map.merge(context, output)}

          {:error, reason} ->
            result = step_result(step, :failed, %{}, inspect(reason), started_at)
            {:failed, results ++ [result], context}
        end

      :error ->
        result = step_result(step, :failed, %{}, "unknown action_type: #{step["action_type"]}", started_at)
        {:failed, results ++ [result], context}
    end
  end

  defp step_result(step, status, output, error, started_at \\ nil) do
    %{
      "position" => step["position"],
      "action_type" => step["action_type"],
      "status" => to_string(status),
      "output" => output,
      "error" => error,
      "started_at" => started_at && DateTime.to_iso8601(started_at),
      "finished_at" => started_at && DateTime.to_iso8601(DateTime.utc_now(:second))
    }
  end
end
