# AIDEV-NOTE: Storybook story for StatusBadge components

defmodule Storybook.CoreComponents.StatusBadge do
  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.StatusBadge.status_badge/1
  def imports, do: [{PremiereEcouteWeb.Components.StatusBadge, [status_badge: 1, session_status_badge: 1, user_status_badge: 1]}]

  def template do
    """
    <.psb-variation/>
    """
  end

  def variations do
    [
      %Variation{
        id: :session_statuses,
        description: "Session status badges",
        template: """
        <div class="flex items-center space-x-4">
          <.session_status_badge status={:preparing} />
          <.session_status_badge status={:active} />
          <.session_status_badge status={:stopped} />
        </div>
        """
      },
      %Variation{
        id: :user_statuses,
        description: "User status badges",
        template: """
        <div class="flex items-center space-x-4">
          <.user_status_badge status={:online} />
          <.user_status_badge status={:offline} />
        </div>
        """
      },
      %Variation{
        id: :variants,
        description: "Different color variants",
        template: """
        <div class="flex flex-wrap gap-3">
          <.status_badge status="Active" variant="success" />
          <.status_badge status="Pending" variant="warning" />
          <.status_badge status="Error" variant="error" />
          <.status_badge status="Info" variant="info" />
          <.status_badge status="Primary" variant="primary" />
          <.status_badge status="Neutral" variant="neutral" />
        </div>
        """
      },
      %Variation{
        id: :sizes,
        description: "Different size variants",
        template: """
        <div class="space-y-4">
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Small</h3>
            <div class="flex items-center space-x-3">
              <.status_badge status="Active" variant="success" size="sm" />
              <.status_badge status="Pending" variant="warning" size="sm" />
              <.status_badge status="Error" variant="error" size="sm" />
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Medium (default)</h3>
            <div class="flex items-center space-x-3">
              <.status_badge status="Active" variant="success" size="md" />
              <.status_badge status="Pending" variant="warning" size="md" />
              <.status_badge status="Error" variant="error" size="md" />
            </div>
          </div>
          
          <div>
            <h3 class="text-sm font-medium text-gray-300 mb-2">Large</h3>
            <div class="flex items-center space-x-3">
              <.status_badge status="Active" variant="success" size="lg" />
              <.status_badge status="Pending" variant="warning" size="lg" />
              <.status_badge status="Error" variant="error" size="lg" />
            </div>
          </div>
        </div>
        """
      },
      %Variation{
        id: :custom_content,
        description: "Custom text and icons",
        template: """
        <div class="flex flex-wrap gap-3">
          <.status_badge status="custom" text="Processing..." icon="⚡" variant="info" />
          <.status_badge status="custom" text="Completed" icon="✅" variant="success" />
          <.status_badge status="custom" text="Failed" icon="❌" variant="error" />
          <.status_badge status="custom" text="Scheduled" icon="📅" variant="neutral" />
        </div>
        """
      },
      %Variation{
        id: :without_borders,
        description: "Status badges without borders",
        template: """
        <div class="flex flex-wrap gap-3">
          <.status_badge status="Active" variant="success" border={false} />
          <.status_badge status="Pending" variant="warning" border={false} />
          <.status_badge status="Error" variant="error" border={false} />
          <.status_badge status="Info" variant="info" border={false} />
        </div>
        """
      },
      %Variation{
        id: :without_icons,
        description: "Status badges without icons",
        template: """
        <div class="flex flex-wrap gap-3">
          <.status_badge status={:preparing} type="session" show_icon={false} />
          <.status_badge status={:active} type="session" show_icon={false} />
          <.status_badge status={:stopped} type="session" show_icon={false} />
        </div>
        """
      },
      %Variation{
        id: :system_statuses,
        description: "System status examples",
        template: """
        <div class="space-y-3">
          <div class="flex items-center justify-between p-3 bg-gray-800 rounded-lg">
            <span class="text-gray-300">Database Connection</span>
            <.status_badge status="Connected" type="system" />
          </div>
          
          <div class="flex items-center justify-between p-3 bg-gray-800 rounded-lg">
            <span class="text-gray-300">Spotify API</span>
            <.status_badge status="error" type="system" />
          </div>
          
          <div class="flex items-center justify-between p-3 bg-gray-800 rounded-lg">
            <span class="text-gray-300">Background Jobs</span>
            <.status_badge status="warning" type="system" />
          </div>
        </div>
        """
      }
    ]
  end
end