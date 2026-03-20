defmodule PremiereEcoute.Notifications.Types.AutomationSuccess do
  @moduledoc """
  Notification type for automation run successes.

  Dispatched by `AutomationExecution` when all steps complete successfully.
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
  def type, do: "automation_success"

  @impl true
  def channels, do: [:pubsub]

  @impl true
  def render(%__MODULE__{automation_name: name, run_id: run_id, automation_id: auto_id}),
    do: render(%{"automation_name" => name, "run_id" => run_id, "automation_id" => auto_id})

  def render(%{"automation_name" => name, "run_id" => run_id, "automation_id" => auto_id}) do
    %{
      title: "Automation completed: #{name}",
      body: "All steps ran successfully.",
      icon: "check-circle",
      path: "/playlists/automations/#{auto_id}?run=#{run_id}"
    }
  end
end
