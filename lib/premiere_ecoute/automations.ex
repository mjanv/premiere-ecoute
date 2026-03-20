defmodule PremiereEcoute.Automations do
  @moduledoc """
  Public context for playlist automations.

  All external callers use this module — internal schemas, services, and workers
  are not part of the public API.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Playlists.Automations.ActionRegistry
  alias PremiereEcoute.Playlists.Automations.Automation
  alias PremiereEcoute.Playlists.Automations.AutomationRun
  alias PremiereEcoute.Playlists.Automations.Services.AutomationCreation
  alias PremiereEcoute.Playlists.Automations.Services.AutomationScheduling
  alias PremiereEcoute.Repo

  import Ecto.Query

  @doc "Lists all automations for a user."
  defdelegate list_automations(user), to: Automation, as: :list_for_user

  @doc "Gets a single automation by id for a user, with virtual fields populated."
  @spec get_automation(User.t(), integer()) :: Automation.t() | nil
  defdelegate get_automation(user, id), to: Automation, as: :get_with_virtual_fields

  @doc "Creates an automation and schedules its first run."
  defdelegate create_automation(user, attrs), to: AutomationCreation, as: :create

  @doc "Updates an automation, cancelling and rescheduling as needed."
  defdelegate update_automation(automation, attrs), to: AutomationCreation, as: :update

  @doc "Enables an automation."
  defdelegate enable_automation(automation), to: AutomationCreation, as: :enable

  @doc "Disables an automation."
  defdelegate disable_automation(automation), to: AutomationCreation, as: :disable

  @doc "Deletes an automation and cancels pending jobs."
  defdelegate delete_automation(automation), to: AutomationCreation, as: :delete

  @doc "Schedules the appropriate job for an automation based on its schedule field."
  defdelegate schedule(automation), to: AutomationScheduling

  @doc "Lists automations that reference a given playlist_id in any step config."
  @spec list_for_playlist(User.t(), String.t()) :: [Automation.t()]
  def list_for_playlist(%User{id: user_id}, playlist_id) do
    Automation
    |> where([a], a.user_id == ^user_id)
    |> where(
      [a],
      fragment(
        "EXISTS (SELECT 1 FROM jsonb_array_elements(?) AS step WHERE step->'config'->>'playlist_id' = ?)",
        a.steps,
        ^playlist_id
      )
    )
    |> Repo.all()
  end

  @doc "Returns a map of playlist_id => automation count for a list of playlist_ids."
  @spec automation_counts(User.t(), [String.t()]) :: %{String.t() => non_neg_integer()}
  def automation_counts(%User{id: user_id}, playlist_ids) when playlist_ids != [] do
    rows =
      Automation
      |> where([a], a.user_id == ^user_id)
      |> select([a], a.steps)
      |> Repo.all()

    Enum.reduce(rows, %{}, fn steps, acc ->
      steps
      |> Enum.flat_map(fn step -> [get_in(step, ["config", "playlist_id"])] end)
      |> Enum.filter(&(&1 in playlist_ids))
      |> Enum.uniq()
      |> Enum.reduce(acc, fn pid, inner -> Map.update(inner, pid, 1, &(&1 + 1)) end)
    end)
  end

  def automation_counts(_user, []), do: %{}

  @doc "Lists run history for an automation."
  defdelegate list_runs(automation), to: AutomationRun, as: :list_for_automation

  @doc "Returns all registered action types and their modules."
  @spec action_registry() :: %{String.t() => module()}
  def action_registry, do: ActionRegistry.all()
end
