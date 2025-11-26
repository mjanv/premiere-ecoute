defmodule Storybook.CoreComponents.Flash do
  @moduledoc """
  Storybook for flash component.

  Displays variations of the flash message component including info and error messages.
  """

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.CoreComponents.flash/1
  def imports, do: [{PremiereEcouteWeb.CoreComponents, show: 1, button: 1}]
  def render_source, do: :function

  def template do
    """
    <div>
      <.button phx-click={show("#:variation_id")}>
        Trigger flash
      </.button>
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :info,
        description: "Info message",
        attributes: %{
          kind: :info,
          hidden: true,
          title: "Did you know?"
        },
        slots: ["Flash message"]
      },
      %Variation{
        id: :error,
        description: "Error message",
        attributes: %{
          kind: :error,
          hidden: true,
          title: "Oops!"
        },
        slots: ["Sorry, it just crashed"]
      }
    ]
  end
end
