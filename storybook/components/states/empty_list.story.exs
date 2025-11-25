defmodule Storybook.Components.EmptyList do
  @moduledoc """
  Storybook for empty list component.

  Displays variations of empty list states with different messages, action buttons, and icons.
  """

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.EmptyState.empty_list/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :basic_messages,
        variations: [
          %Variation{
            id: :no_items,
            attributes: %{
              message: "No items found",
              icon: "hero-inbox"
            }
          },
          %Variation{
            id: :no_playlists,
            attributes: %{
              message: "No playlists in your library",
              icon: "hero-queue-list"
            }
          },
          %Variation{
            id: :no_sessions,
            attributes: %{
              message: "No listening sessions available",
              icon: "hero-users"
            }
          },
          %Variation{
            id: :no_votes,
            attributes: %{
              message: "No votes recorded yet",
              icon: "hero-hand-thumb-up"
            }
          }
        ]
      },
      %VariationGroup{
        id: :with_actions,
        variations: [
          %Variation{
            id: :clear_search_action,
            attributes: %{
              message: "No results match your search",
              icon: "hero-magnifying-glass"
            },
            slots: [
              """
              <:action>
                <button class="text-purple-400 hover:text-purple-300 font-medium">
                  Clear search
                </button>
              </:action>
              """
            ]
          },
          %Variation{
            id: :add_item_action,
            attributes: %{
              message: "Your collection is empty",
              icon: "hero-folder"
            },
            slots: [
              """
              <:action>
                <button class="inline-flex items-center px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                  </svg>
                  Add Item
                </button>
              </:action>
              """
            ]
          }
        ]
      },
      %VariationGroup{
        id: :different_icons,
        variations: [
          %Variation{
            id: :heart_icon,
            attributes: %{
              message: "No favorites yet",
              icon: "hero-heart"
            }
          },
          %Variation{
            id: :star_icon,
            attributes: %{
              message: "No ratings available",
              icon: "hero-star"
            }
          },
          %Variation{
            id: :clock_icon,
            attributes: %{
              message: "No recent activity",
              icon: "hero-clock"
            }
          },
          %Variation{
            id: :musical_note_icon,
            attributes: %{
              message: "No tracks found",
              icon: "hero-musical-note"
            }
          }
        ]
      }
    ]
  end
end
