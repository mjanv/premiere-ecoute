defmodule Storybook.Components.Navigation.PageHeader do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.PageHeader.page_header/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :basic,
        variations: [
          %Variation{
            id: :title_only,
            attributes: %{
              title: "My Sessions"
            }
          },
          %Variation{
            id: :with_subtitle,
            attributes: %{
              title: "My Sessions",
              subtitle: "Manage your listening sessions and track your music discoveries"
            }
          }
        ]
      },
      %VariationGroup{
        id: :with_actions,
        variations: [
          %Variation{
            id: :single_action,
            attributes: %{
              title: "My Billboards",
              subtitle: "Manage your music billboard campaigns and collect playlist submissions"
            },
            slots: [
              """
              <:action>
                <button class="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors font-medium shadow-lg flex items-center">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  New Billboard
                </button>
              </:action>
              """
            ]
          },
          %Variation{
            id: :multiple_actions,
            attributes: %{
              title: "My Library",
              subtitle: "Manage your saved playlists and discover new music"
            },
            slots: [
              """
              <:action>
                <button class="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg transition-colors font-medium flex items-center">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
                  </svg>
                  Filter
                </button>
              </:action>
              <:action>
                <button class="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors font-medium shadow-lg flex items-center">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  Add Playlist
                </button>
              </:action>
              """
            ]
          }
        ]
      }
    ]
  end
end
