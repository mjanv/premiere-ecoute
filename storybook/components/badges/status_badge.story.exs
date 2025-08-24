defmodule Storybook.Components.StatusBadge do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.StatusBadge.status_badge/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :statuses,
        variations: [
          %Variation{
            id: :active,
            attributes: %{status: :active}
          },
          %Variation{
            id: :preparing,
            attributes: %{status: :preparing}
          },
          %Variation{
            id: :completed,
            attributes: %{status: "completed"}
          },
          %Variation{
            id: :stopped,
            attributes: %{status: "stopped"}
          }
        ]
      },
      %VariationGroup{
        id: :variants,
        variations: [
          %Variation{
            id: :success,
            attributes: %{variant: "success"}
          },
          %Variation{
            id: :warning,
            attributes: %{variant: "warning"}
          },
          %Variation{
            id: :error,
            attributes: %{variant: "error"}
          },
          %Variation{
            id: :info,
            attributes: %{variant: "info"}
          },
          %Variation{
            id: :primary,
            attributes: %{variant: "primary"}
          },
          %Variation{
            id: :secondary,
            attributes: %{variant: "secondary"}
          }
        ]
      },
      %VariationGroup{
        id: :sizes,
        variations: [
          %Variation{
            id: :xs,
            attributes: %{status: "active", size: "xs"}
          },
          %Variation{
            id: :sm,
            attributes: %{status: "active", size: "sm"}
          },
          %Variation{
            id: :md,
            attributes: %{status: "active", size: "md"}
          },
          %Variation{
            id: :lg,
            attributes: %{status: "active", size: "lg"}
          }
        ]
      },
      %VariationGroup{
        id: :with_icons,
        variations: [
          %Variation{
            id: :check_icon,
            attributes: %{
              status: "active",
              icon: "hero-check-circle"
            }
          },
          %Variation{
            id: :warning_icon,
            attributes: %{
              status: "preparing",
              icon: "hero-exclamation-triangle"
            }
          },
          %Variation{
            id: :error_icon,
            attributes: %{
              status: "stopped",
              icon: "hero-x-circle"
            }
          }
        ]
      },
      %VariationGroup{
        id: :custom_content,
        variations: [
          %Variation{
            id: :custom_text,
            attributes: %{
              variant: "success",
              icon: "hero-check-circle"
            },
            slots: ["Custom Success Message"]
          }
        ]
      }
    ]
  end
end
