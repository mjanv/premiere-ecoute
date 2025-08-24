defmodule Storybook.Components.SkeletonElement do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.LoadingState.skeleton_element/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :types,
        variations: [
          %Variation{
            id: :text,
            attributes: %{type: "text"}
          },
          %Variation{
            id: :title,
            attributes: %{type: "title"}
          },
          %Variation{
            id: :avatar,
            attributes: %{type: "avatar"}
          },
          %Variation{
            id: :button,
            attributes: %{type: "button"}
          },
          %Variation{
            id: :card,
            attributes: %{type: "card"}
          },
          %Variation{
            id: :image,
            attributes: %{type: "image"}
          }
        ]
      },
      %VariationGroup{
        id: :widths,
        variations: [
          %Variation{
            id: :full_width,
            attributes: %{type: "text", width: "full"}
          },
          %Variation{
            id: :three_quarters,
            attributes: %{type: "text", width: "3/4"}
          },
          %Variation{
            id: :half_width,
            attributes: %{type: "text", width: "1/2"}
          },
          %Variation{
            id: :quarter_width,
            attributes: %{type: "text", width: "1/4"}
          }
        ]
      },
      %VariationGroup{
        id: :avatar_sizes,
        variations: [
          %Variation{
            id: :avatar_xs,
            attributes: %{type: "avatar", size: "xs"}
          },
          %Variation{
            id: :avatar_sm,
            attributes: %{type: "avatar", size: "sm"}
          },
          %Variation{
            id: :avatar_md,
            attributes: %{type: "avatar", size: "md"}
          },
          %Variation{
            id: :avatar_lg,
            attributes: %{type: "avatar", size: "lg"}
          },
          %Variation{
            id: :avatar_xl,
            attributes: %{type: "avatar", size: "xl"}
          }
        ]
      },
      %VariationGroup{
        id: :custom_heights,
        variations: [
          %Variation{
            id: :image_small,
            attributes: %{type: "image", height: "24"}
          },
          %Variation{
            id: :image_medium,
            attributes: %{type: "image", height: "32"}
          },
          %Variation{
            id: :image_large,
            attributes: %{type: "image", height: "48"}
          },
          %Variation{
            id: :card_tall,
            attributes: %{type: "card", height: "32"}
          }
        ]
      }
    ]
  end
end