defmodule Storybook.Components.LoadingSpinner do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.LoadingState.loading_spinner/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :sizes,
        variations: [
          %Variation{
            id: :xs,
            attributes: %{size: "xs"}
          },
          %Variation{
            id: :sm,
            attributes: %{size: "sm"}
          },
          %Variation{
            id: :md,
            attributes: %{size: "md"}
          },
          %Variation{
            id: :lg,
            attributes: %{size: "lg"}
          },
          %Variation{
            id: :xl,
            attributes: %{size: "xl"}
          }
        ]
      },
      %VariationGroup{
        id: :colors,
        variations: [
          %Variation{
            id: :default,
            attributes: %{size: "md"}
          },
          %Variation{
            id: :blue,
            attributes: %{size: "md", class: "text-blue-500"}
          },
          %Variation{
            id: :green,
            attributes: %{size: "md", class: "text-green-500"}
          },
          %Variation{
            id: :purple,
            attributes: %{size: "md", class: "text-purple-500"}
          },
          %Variation{
            id: :red,
            attributes: %{size: "md", class: "text-red-500"}
          }
        ]
      }
    ]
  end
end
