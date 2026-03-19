defmodule PremiereEcoute.Notifications.Types.AutomationFailure do
  @moduledoc """
  Notification type for automation run failures.

  Dispatched by `AutomationExecution` when a step fails.
  """

  @behaviour PremiereEcoute.Notifications.NotificationType

  @enforce_keys [:automation_id, :automation_name, :run_id]
  defstruct [:automation_id, :automation_name, :run_id]

  @type t :: %__MODULE__{
          automation_id: integer(),
          automation_name: String.t(),
          run_id: integer()
        }

  @impl true
  def type, do: "automation_failure"

  @impl true
  def channels, do: [:pubsub]

  @impl true
  def render(%__MODULE__{automation_name: name, run_id: run_id, automation_id: auto_id}),
    do: render(%{"automation_name" => name, "run_id" => run_id, "automation_id" => auto_id})

  def render(%{"automation_name" => name, "run_id" => run_id, "automation_id" => auto_id}) do
    %{
      title: "Automation failed: #{name}",
      body: "One or more steps encountered an error and the run was stopped.",
      icon: "exclamation-circle",
      path: "/playlists/automations/#{auto_id}?run=#{run_id}"
    }
  end
end
