defmodule Storybook.Components.EmptyState do
  @moduledoc """
  Storybook for empty state component.

  Displays variations of empty state components with different sizes, contexts, action buttons, error states, and icons.
  """

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.EmptyState.empty_state/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :sizes,
        variations: [
          %Variation{
            id: :sm,
            attributes: %{
              icon: "hero-musical-note",
              title: "No Albums Yet",
              description: "You haven't added any albums to your library.",
              size: "sm"
            }
          },
          %Variation{
            id: :md,
            attributes: %{
              icon: "hero-musical-note",
              title: "No Albums Yet",
              description: "You haven't added any albums to your library.",
              size: "md"
            }
          },
          %Variation{
            id: :lg,
            attributes: %{
              icon: "hero-musical-note",
              title: "No Albums Yet",
              description: "You haven't added any albums to your library.",
              size: "lg"
            }
          }
        ]
      },
      %VariationGroup{
        id: :different_contexts,
        variations: [
          %Variation{
            id: :no_playlists,
            attributes: %{
              icon: "hero-queue-list",
              title: "No Playlists",
              description: "Your playlist library is empty. Start building your music collection."
            }
          },
          %Variation{
            id: :no_sessions,
            attributes: %{
              icon: "hero-users",
              title: "No Listening Sessions",
              description: "No listening sessions have been created yet. Create your first session to start sharing music."
            }
          },
          %Variation{
            id: :no_billboards,
            attributes: %{
              icon: "hero-megaphone",
              title: "No Billboards",
              description: "You haven't created any music billboards yet. Get started by creating your first billboard."
            }
          },
          %Variation{
            id: :no_votes,
            attributes: %{
              icon: "hero-hand-thumb-up",
              title: "No Votes Yet",
              description: "No one has voted on this track yet. Be the first to share your opinion!"
            }
          }
        ]
      },
      %VariationGroup{
        id: :with_actions,
        variations: [
          %Variation{
            id: :create_playlist_action,
            attributes: %{
              icon: "hero-plus-circle",
              title: "Create Your First Playlist",
              description: "Start building your music collection by adding playlists from Spotify."
            },
            slots: [
              """
              <:action>
                <button class="inline-flex items-center px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                  </svg>
                  Add Playlist
                </button>
              </:action>
              """
            ]
          },
          %Variation{
            id: :start_session_action,
            attributes: %{
              icon: "hero-play",
              title: "Start Your First Session",
              description: "Share music with your community by creating a listening session."
            },
            slots: [
              """
              <:action>
                <button class="inline-flex items-center px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-medium transition-colors">
                  <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>
                  </svg>
                  Create Session
                </button>
              </:action>
              """
            ]
          }
        ]
      },
      %VariationGroup{
        id: :error_states,
        variations: [
          %Variation{
            id: :connection_error,
            attributes: %{
              icon: "hero-wifi",
              title: "Connection Lost",
              description: "We're having trouble connecting to your music service. Please check your internet connection."
            },
            slots: [
              """
              <:action>
                <button class="inline-flex items-center px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg font-medium transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  Retry
                </button>
              </:action>
              """
            ]
          },
          %Variation{
            id: :permission_denied,
            attributes: %{
              icon: "hero-lock-closed",
              title: "Access Denied",
              description: "You don't have permission to view this content. Please contact an administrator for access."
            }
          }
        ]
      },
      %VariationGroup{
        id: :different_icons,
        variations: [
          %Variation{
            id: :folder,
            attributes: %{
              icon: "hero-folder",
              title: "No Files",
              description: "This folder is empty."
            }
          },
          %Variation{
            id: :heart,
            attributes: %{
              icon: "hero-heart",
              title: "No Favorites",
              description: "You haven't favorited any tracks yet."
            }
          },
          %Variation{
            id: :clock,
            attributes: %{
              icon: "hero-clock",
              title: "No History",
              description: "Your listening history is empty."
            }
          },
          %Variation{
            id: :star,
            attributes: %{
              icon: "hero-star",
              title: "No Reviews",
              description: "No one has reviewed this album yet."
            }
          }
        ]
      }
    ]
  end
end
