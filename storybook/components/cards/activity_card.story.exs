defmodule Storybook.Components.Cards.ActivityCard do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.ActivityCard.activity_card/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :content_cards,
        description: "Cards showing existing user content",
        variations: [
          %Variation{
            id: :active_session,
            description: "Active listening session with album cover",
            attributes: %{
              type: "content",
              label: "Active Session",
              title: "Abbey Road",
              subtitle: "by The Beatles",
              status_text: "Live",
              status_variant: "success",
              action_text: "Continue session",
              navigate: "/sessions/123"
            },
            slots: [
              """
              <:icon>
                <img
                  src="https://i.scdn.co/image/ab67616d0000b273dc30583ba717007b00cceb25"
                  alt="Abbey Road"
                  class="w-16 h-16 rounded-lg object-cover shadow-md"
                />
              </:icon>
              """
            ]
          },
          %Variation{
            id: :preparing_session,
            description: "Session in preparing state with album cover",
            attributes: %{
              type: "content",
              label: "Active Session",
              title: "The Dark Side of the Moon",
              subtitle: "by Pink Floyd",
              status_text: "Ready",
              status_variant: "warning",
              action_text: "Start session",
              navigate: "/sessions/456"
            },
            slots: [
              """
              <:icon>
                <img
                  src="https://i.scdn.co/image/ab67616d0000b273ea7caaff71dea1051d49b2fe"
                  alt="The Dark Side of the Moon"
                  class="w-16 h-16 rounded-lg object-cover shadow-md"
                />
              </:icon>
              """
            ]
          },
          %Variation{
            id: :active_billboard,
            description: "Active billboard with submissions",
            attributes: %{
              type: "content",
              label: "Latest Billboard",
              title: "Best Summer Vibes 2024",
              subtitle: "3 submissions",
              status_text: "Active",
              status_variant: "success",
              action_text: "Manage billboard",
              navigate: "/billboards/789"
            }
          },
          %Variation{
            id: :stopped_billboard,
            description: "Stopped billboard for viewing results",
            attributes: %{
              type: "content",
              label: "Latest Billboard",
              title: "Winter Chill Collection",
              subtitle: "15 submissions",
              status_text: "Stopped",
              status_variant: "danger",
              action_text: "View results",
              navigate: "/billboards/101"
            }
          }
        ]
      },
      %VariationGroup{
        id: :action_cards,
        description: "Cards prompting users to create new content",
        variations: [
          %Variation{
            id: :create_session,
            description: "Create new listening session",
            attributes: %{
              type: "action",
              label: "Create Session",
              title: "Start Listening Session",
              subtitle: "Share music with your community",
              status_text: "New",
              status_variant: "info",
              action_text: "Choose an album to get started",
              navigate: "/sessions/new"
            }
          },
          %Variation{
            id: :create_billboard,
            description: "Create new music billboard",
            attributes: %{
              type: "action",
              label: "Create Billboard",
              title: "Create Music Billboard",
              subtitle: "Collect community playlists",
              status_text: "New",
              status_variant: "default",
              action_text: "Start collecting submissions",
              navigate: "/billboards/new"
            }
          }
        ]
      },
      %VariationGroup{
        id: :disabled_cards,
        description: "Cards for unavailable features",
        variations: [
          %Variation{
            id: :sessions_disabled,
            description: "Sessions feature disabled",
            attributes: %{
              type: "disabled",
              title: "Sessions not available"
            }
          },
          %Variation{
            id: :billboards_disabled,
            description: "Billboards feature disabled",
            attributes: %{
              type: "disabled",
              title: "Billboards not available"
            }
          }
        ]
      },
      %VariationGroup{
        id: :status_variants,
        description: "Different status badge colors",
        variations: [
          %Variation{
            id: :success_status,
            attributes: %{
              type: "content",
              label: "Status Example",
              title: "Success Status",
              subtitle: "Green status badge",
              status_text: "Active",
              status_variant: "success",
              action_text: "View details"
            }
          },
          %Variation{
            id: :warning_status,
            attributes: %{
              type: "content",
              label: "Status Example",
              title: "Warning Status",
              subtitle: "Amber status badge",
              status_text: "Pending",
              status_variant: "warning",
              action_text: "Take action"
            }
          },
          %Variation{
            id: :info_status,
            attributes: %{
              type: "content",
              label: "Status Example",
              title: "Info Status",
              subtitle: "Blue status badge",
              status_text: "Processing",
              status_variant: "info",
              action_text: "Monitor progress"
            }
          },
          %Variation{
            id: :danger_status,
            attributes: %{
              type: "content",
              label: "Status Example",
              title: "Danger Status",
              subtitle: "Red status badge",
              status_text: "Failed",
              status_variant: "danger",
              action_text: "Fix issue"
            }
          }
        ]
      },
      %VariationGroup{
        id: :custom_icons,
        description: "Cards with custom icon content",
        variations: [
          %Variation{
            id: :with_avatar,
            description: "Card with user avatar",
            attributes: %{
              type: "content",
              label: "Recent Activity",
              title: "Collaboration Session",
              subtitle: "with Alex Johnson",
              status_text: "Complete",
              status_variant: "success",
              action_text: "View session"
            },
            slots: [
              """
              <:icon>
                <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-pink-500 rounded-lg flex items-center justify-center">
                  <span class="text-white font-bold text-lg">AJ</span>
                </div>
              </:icon>
              """
            ]
          },
          %Variation{
            id: :with_custom_svg,
            description: "Card with custom SVG icon",
            attributes: %{
              type: "action",
              label: "Library Action",
              title: "Import Spotify Playlists",
              subtitle: "Sync your music library",
              status_text: "Available",
              status_variant: "info",
              action_text: "Connect Spotify"
            },
            slots: [
              """
              <:icon>
                <div class="w-16 h-16 bg-gradient-to-br from-green-500/30 to-green-600/20 rounded-lg flex items-center justify-center">
                  <svg class="w-8 h-8 text-green-400" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.42 1.56-.299.421-1.02.599-1.559.3z"/>
                  </svg>
                </div>
              </:icon>
              """
            ]
          }
        ]
      },
      %VariationGroup{
        id: :real_examples,
        description: "Real examples from the application",
        template: """
        <div class="flex gap-6" psb-code-hidden>
          <.psb-variation/>
        </div>
        """,
        variations: [
          %Variation{
            id: :home_dashboard_pair,
            description: "Session and Billboard cards as shown on home dashboard",
            attributes: %{
              type: "content",
              label: "Active Session",
              title: "Random Access Memories",
              subtitle: "by Daft Punk",
              status_text: "Live",
              status_variant: "success",
              action_text: "Continue session",
              navigate: "/sessions/example"
            },
            slots: [
              """
              <:icon>
                <img
                  src="https://i.scdn.co/image/ab67616d0000b273da6f73a25f4c79d0e6b4a8bd"
                  alt="Random Access Memories"
                  class="w-16 h-16 rounded-lg object-cover shadow-md"
                />
              </:icon>
              """
            ]
          }
        ]
      }
    ]
  end
end
