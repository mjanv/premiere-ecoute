defmodule Storybook.Components.Modal do
  @moduledoc """
  Storybook for modal component.

  Displays variations of modal dialogs with backdrop and interactive close functionality.
  """

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.Modal.modal/1
  def render_source, do: :function

  def variations do
    [
      %Variation{
        id: :modal_demo,
        template: """
        <div class="space-y-4">
          <details class="border border-gray-300 rounded-lg p-4">
            <summary class="cursor-pointer font-medium text-blue-600 hover:text-blue-800">Click to open modal preview</summary>
            <div class="mt-4 p-4 bg-gray-50 rounded border-2 border-dashed border-gray-300">
              <.psb-variation/>
            </div>
          </details>
        </div>
        """,
        attributes: %{
          id: "demo-modal",
          show: true,
          class: "relative",
          on_cancel: Phoenix.LiveView.JS.push("hide_modal")
        },
        slots: [
          """
          <p class="text-gray-600">This is how a modal appears with backdrop and content. In a real LiveView application, clicking outside or the X button would close it via Phoenix LiveView events.</p>
          """
        ]
      }
    ]
  end
end
