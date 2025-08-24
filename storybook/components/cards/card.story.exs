defmodule Storybook.Components.Card do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.Card.card/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :variants,
        variations: [
          %Variation{
            id: :default,
            attributes: %{variant: "default"},
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2">Default Card</h3>
                <p class="text-gray-600">This is a default card with basic styling and neutral colors.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :primary,
            attributes: %{variant: "primary"},
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2 text-white">Primary Card</h3>
                <p class="text-blue-100">This is a primary card with blue gradient background and accent colors.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :success,
            attributes: %{variant: "success"},
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2 text-white">Success Card</h3>
                <p class="text-green-100">This is a success card with green gradient background for positive actions.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :warning,
            attributes: %{variant: "warning"},
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2 text-white">Warning Card</h3>
                <p class="text-amber-100">This is a warning card with amber gradient background for cautionary content.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :danger,
            attributes: %{variant: "danger"},
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2 text-white">Danger Card</h3>
                <p class="text-red-100">This is a danger card with red gradient background for error states.</p>
              </div>
              """
            ]
          }
        ]
      },
      %VariationGroup{
        id: :content_examples,
        variations: [
          %Variation{
            id: :with_header,
            attributes: %{variant: "default"},
            slots: [
              """
              <div class="border-b px-6 py-4">
                <h3 class="text-lg font-semibold">Card Header</h3>
              </div>
              <div class="p-6">
                <p class="text-gray-600">This card has a header section separated from the main content area.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :with_footer,
            attributes: %{variant: "default"},
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2">Card with Footer</h3>
                <p class="text-gray-600">This card includes a footer section with action buttons.</p>
              </div>
              <div class="border-t px-6 py-4 bg-gray-50 rounded-b-lg">
                <div class="flex justify-end space-x-3">
                  <button class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800">Cancel</button>
                  <button class="px-4 py-2 text-sm bg-blue-600 text-white rounded hover:bg-blue-700">Save</button>
                </div>
              </div>
              """
            ]
          },
          %Variation{
            id: :stats_layout,
            attributes: %{variant: "default"},
            slots: [
              """
              <div class="p-6">
                <div class="grid grid-cols-3 gap-4 text-center">
                  <div>
                    <div class="text-2xl font-bold text-blue-600">1,234</div>
                    <div class="text-sm text-gray-500">Users</div>
                  </div>
                  <div>
                    <div class="text-2xl font-bold text-green-600">98%</div>
                    <div class="text-sm text-gray-500">Uptime</div>
                  </div>
                  <div>
                    <div class="text-2xl font-bold text-purple-600">456</div>
                    <div class="text-sm text-gray-500">Sessions</div>
                  </div>
                </div>
              </div>
              """
            ]
          }
        ]
      },
      %VariationGroup{
        id: :interactive,
        template: """
        <div class="space-y-4" psb-code-hidden>
          <.psb-variation/>
        </div>
        """,
        variations: [
          %Variation{
            id: :hoverable,
            attributes: %{
              variant: "default",
              class: "hover:shadow-lg hover:scale-105 transition-all cursor-pointer"
            },
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2">Hoverable Card</h3>
                <p class="text-gray-600">Hover over this card to see the interactive effect with shadow and scale.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :clickable_primary,
            attributes: %{
              variant: "primary",
              class: "hover:opacity-90 transition-opacity cursor-pointer"
            },
            slots: [
              """
              <div class="p-6">
                <h3 class="text-lg font-semibold mb-2 text-white">Clickable Primary Card</h3>
                <p class="text-blue-100">This card has hover effects to indicate it's clickable.</p>
              </div>
              """
            ]
          }
        ]
      },
      %VariationGroup{
        id: :sizing,
        variations: [
          %Variation{
            id: :compact,
            attributes: %{variant: "default"},
            slots: [
              """
              <div class="p-4">
                <h4 class="font-medium mb-1">Compact Card</h4>
                <p class="text-sm text-gray-600">Smaller padding for dense layouts.</p>
              </div>
              """
            ]
          },
          %Variation{
            id: :spacious,
            attributes: %{variant: "default"},
            slots: [
              """
              <div class="p-8">
                <h3 class="text-xl font-semibold mb-4">Spacious Card</h3>
                <p class="text-gray-600 leading-relaxed">More generous padding and spacing for important content that needs breathing room.</p>
              </div>
              """
            ]
          }
        ]
      }
    ]
  end
end
