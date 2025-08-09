# AIDEV-NOTE: Storybook story for LoadingState components

defmodule Storybook.CoreComponents.LoadingState do
  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.LoadingState.spinner/1
  def imports, do: [{PremiereEcouteWeb.Components.LoadingState, [spinner: 1, skeleton_text: 1, skeleton_card: 1, loading_overlay: 1, loading_inline: 1, pulse_indicator: 1]}]

  def template do
    """
    <.psb-variation/>
    """
  end

  def variations do
    [
      %Variation{
        id: :spinners,
        description: "Spinning loading indicators",
        template: """
        <div class="space-y-6">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Sizes</h3>
            <div class="flex items-center space-x-6">
              <div class="text-center">
                <.spinner size="sm" />
                <p class="text-xs text-gray-400 mt-2">Small</p>
              </div>
              <div class="text-center">
                <.spinner size="md" />
                <p class="text-xs text-gray-400 mt-2">Medium</p>
              </div>
              <div class="text-center">
                <.spinner size="lg" />
                <p class="text-xs text-gray-400 mt-2">Large</p>
              </div>
              <div class="text-center">
                <.spinner size="xl" />
                <p class="text-xs text-gray-400 mt-2">Extra Large</p>
              </div>
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Colors</h3>
            <div class="flex items-center space-x-6">
              <div class="text-center">
                <.spinner color="primary" />
                <p class="text-xs text-gray-400 mt-2">Primary</p>
              </div>
              <div class="text-center">
                <.spinner color="secondary" />
                <p class="text-xs text-gray-400 mt-2">Secondary</p>
              </div>
              <div class="text-center">
                <.spinner color="white" />
                <p class="text-xs text-gray-400 mt-2">White</p>
              </div>
              <div class="text-center">
                <.spinner color="gray" />
                <p class="text-xs text-gray-400 mt-2">Gray</p>
              </div>
            </div>
          </div>
        </div>
        """
      },
      %Variation{
        id: :skeleton_text,
        description: "Skeleton text loading states",
        template: """
        <div class="space-y-6">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Single line</h3>
            <.skeleton_text lines={1} />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Multiple lines - varied widths</h3>
            <.skeleton_text lines={3} width_variant="varied" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Multiple lines - uniform widths</h3>
            <.skeleton_text lines={4} width_variant="uniform" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Multiple lines - random widths</h3>
            <.skeleton_text lines={5} width_variant="random" />
          </div>
        </div>
        """
      },
      %Variation{
        id: :skeleton_cards,
        description: "Skeleton card loading states",
        template: """
        <div class="space-y-6">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Default card</h3>
            <.skeleton_card variant="default" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Album card</h3>
            <.skeleton_card variant="album" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Session card</h3>
            <.skeleton_card variant="session" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Without image</h3>
            <.skeleton_card show_image={false} />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Without metadata</h3>
            <.skeleton_card show_metadata={false} />
          </div>
        </div>
        """
      },
      %Variation{
        id: :loading_overlays,
        description: "Loading overlays and states",
        template: """
        <div class="space-y-8">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Overlay variant</h3>
            <div class="relative">
              <div class="bg-gray-800 p-6 rounded-lg">
                <p class="text-gray-400">This content is being loaded...</p>
              </div>
              <.loading_overlay variant="overlay" message="Searching albums..." />
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Inline variant</h3>
            <.loading_overlay variant="inline" message="Processing request..." />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Modal variant</h3>
            <div class="bg-gray-800 rounded-lg h-48">
              <.loading_overlay variant="modal" message="Saving changes..." />
            </div>
          </div>
        </div>
        """
      },
      %Variation{
        id: :inline_loading,
        description: "Inline loading indicators",
        template: """
        <div class="space-y-4">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Small inline loading</h3>
            <.loading_inline message="Loading..." size="sm" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Medium inline loading</h3>
            <.loading_inline message="Saving changes..." size="md" />
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">In context</h3>
            <div class="bg-gray-800 p-4 rounded-lg">
              <div class="flex items-center justify-between">
                <span class="text-gray-300">Document status</span>
                <.loading_inline message="Syncing..." />
              </div>
            </div>
          </div>
        </div>
        """
      },
      %Variation{
        id: :pulse_indicators,
        description: "Pulsing active state indicators",
        template: """
        <div class="space-y-6">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Colors</h3>
            <div class="flex items-center space-x-6">
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="green" />
                <span class="text-gray-300 text-sm">Online</span>
              </div>
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="red" />
                <span class="text-gray-300 text-sm">Error</span>
              </div>
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="yellow" />
                <span class="text-gray-300 text-sm">Warning</span>
              </div>
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="purple" />
                <span class="text-gray-300 text-sm">Active Session</span>
              </div>
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="blue" />
                <span class="text-gray-300 text-sm">Processing</span>
              </div>
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Sizes</h3>
            <div class="flex items-center space-x-6">
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="green" size="sm" />
                <span class="text-gray-300 text-sm">Small</span>
              </div>
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="green" size="md" />
                <span class="text-gray-300 text-sm">Medium</span>
              </div>
              <div class="flex items-center space-x-2">
                <.pulse_indicator color="green" size="lg" />
                <span class="text-gray-300 text-sm">Large</span>
              </div>
            </div>
          </div>
        </div>
        """
      },
      %Variation{
        id: :real_world_usage,
        description: "Real-world usage examples",
        template: """
        <div class="space-y-6">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Loading content list</h3>
            <div class="bg-gray-800 rounded-lg p-4 space-y-3">
              <.skeleton_card variant="album" />
              <.skeleton_card variant="album" />
              <.skeleton_card variant="album" />
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-4">Active session status</h3>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="text-white font-medium">Current Session</h4>
                  <p class="text-gray-400 text-sm">Listening to "The Dark Side of the Moon"</p>
                </div>
                <div class="flex items-center space-x-2">
                  <.pulse_indicator color="purple" />
                  <span class="text-purple-400 text-sm">Live</span>
                </div>
              </div>
            </div>
          </div>
        </div>
        """
      }
    ]
  end
end