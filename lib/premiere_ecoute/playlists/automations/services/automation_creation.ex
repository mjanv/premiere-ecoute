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
    with {:ok, automation} <- Automation.insert(user, attrs),
         _ <- AutomationScheduling.schedule(automation) do
      {:ok, automation}
    end
  end

  @doc "Updates an automation, cancels old jobs, and reschedules."
  @spec update(Automation.t(), map()) :: {:ok, Automation.t()} | {:error, term()}
  def update(%Automation{} = automation, attrs) do
    with _ <- AutomationScheduling.cancel(automation),
         {:ok, updated} <- Automation.update(automation, attrs),
         _ <- AutomationScheduling.schedule(updated) do
      {:ok, updated}
    end
  end

  @doc "Enables an automation and reschedules."
  @spec enable(Automation.t()) :: {:ok, Automation.t()} | {:error, term()}
  def enable(%Automation{} = automation) do
    with {:ok, updated} <- Automation.update(automation, %{enabled: true}),
         _ <- AutomationScheduling.schedule(updated) do
      {:ok, updated}
    end
  end

  @doc "Disables an automation and cancels pending jobs."
  @spec disable(Automation.t()) :: {:ok, Automation.t()} | {:error, term()}
  def disable(%Automation{} = automation) do
    with {:ok, updated} <- Automation.update(automation, %{enabled: false}),
         _ <- AutomationScheduling.cancel(updated) do
      {:ok, updated}
    end
  end

  @doc "Deletes an automation and cancels its pending jobs."
  @spec delete(Automation.t()) :: {:ok, Automation.t()} | {:error, term()}
  def delete(%Automation{} = automation) do
    with {:ok, deleted} <- Repo.delete(automation),
         _ <- AutomationScheduling.cancel(deleted) do
      {:ok, deleted}
    end
  end
end
