defmodule Storybook.Components.LoadingOverlay do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.LoadingState.loading_overlay/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :variants,
        template: """
        <div class="relative h-64 bg-gray-100 rounded-lg overflow-hidden" psb-code-hidden>
          <div class="p-4">
            <h3 class="text-lg font-semibold mb-2">Sample Content</h3>
            <p class="text-gray-600">This content would be covered by the loading overlay.</p>
          </div>
          <.psb-variation/>
        </div>
        """,
        variations: [
          %Variation{
            id: :modal_variant,
            attributes: %{
              message: "Loading your music library...",
              variant: "modal",
              class: "relative"
            }
          },
          %Variation{
            id: :overlay_variant,
            attributes: %{
              message: "Searching albums...",
              variant: "overlay"
            }
          }
        ]
      },
      %VariationGroup{
        id: :different_messages,
        template: """
        <div class="relative h-48 bg-gray-100 rounded-lg overflow-hidden" psb-code-hidden>
          <.psb-variation/>
        </div>
        """,
        variations: [
          %Variation{
            id: :loading_playlists,
            attributes: %{
              message: "Loading playlists...",
              variant: "overlay"
            }
          },
          %Variation{
            id: :syncing_data,
            attributes: %{
              message: "Syncing with Spotify...",
              variant: "overlay"
            }
          },
          %Variation{
            id: :processing,
            attributes: %{
              message: "Processing your request...",
              variant: "overlay"
            }
          }
        ]
      }
    ]
  end
end