defmodule PremiereEcoute.Playlists.Automations.Services.AutomationCreation do
  @moduledoc """
  CRUD operations for automations.

  Every write that changes the schedule first cancels existing pending jobs via
  `AutomationScheduling.cancel/1`, then schedules new ones as appropriate.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.Services.AutomationScheduling
  alias PremiereEcoute.Repo

  @doc "Creates an automation and schedules its first run."
  @spec create(User.t(), map()) :: {:ok, Automation.t()} | {:error, term()}
  def create(%User{} = user, attrs) do
    with {:ok, automation} <- Automation.insert(user, attrs) do
      schedule(automation, attrs)
      {:ok, automation}
    end
  end

  @doc "Updates an automation, cancels old jobs, and reschedules."
  @spec update(Automation.t(), map()) :: {:ok, Automation.t()} | {:error, term()}
  def update(%Automation{} = automation, attrs) do
    AutomationScheduling.cancel(automation)

    with {:ok, updated} <- Automation.update(automation, attrs) do
      if updated.enabled, do: schedule(updated, attrs)
      {:ok, updated}
    end
  end

  @doc "Enables an automation and reschedules."
  @spec enable(Automation.t()) :: {:ok, Automation.t()} | {:error, term()}
  def enable(%Automation{} = automation) do
    with {:ok, updated} <- Automation.update(automation, %{enabled: true}) do
      schedule(updated, %{})
      {:ok, updated}
    end
  end

  @doc "Disables an automation and cancels pending jobs."
  @spec disable(Automation.t()) :: {:ok, Automation.t()} | {:error, term()}
  def disable(%Automation{} = automation) do
    AutomationScheduling.cancel(automation)
    Automation.update(automation, %{enabled: false})
  end

  @doc "Deletes an automation and cancels its pending jobs."
  @spec delete(Automation.t()) :: {:ok, Automation.t()} | {:error, term()}
  def delete(%Automation{} = automation) do
    AutomationScheduling.cancel(automation)
    Repo.delete(automation)
  end

  # AIDEV-NOTE: :once schedule_at comes from attrs (caller provides datetime at creation time)
  defp schedule(%Automation{enabled: true, schedule_type: :manual}, _attrs), do: :ok
  defp schedule(%Automation{enabled: true, schedule_type: :recurring} = a, _attrs), do: AutomationScheduling.schedule_next(a)

  defp schedule(%Automation{enabled: true, schedule_type: :once} = a, attrs) do
    case Map.get(attrs, :scheduled_at) || Map.get(attrs, "scheduled_at") do
      nil -> :ok
      at -> AutomationScheduling.schedule(a, at)
    end
  end

  defp schedule(%Automation{enabled: false}, _attrs), do: :ok
end
