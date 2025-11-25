defmodule Storybook.Components.LoadingState do
  @moduledoc """
  Storybook for loading skeleton component.

  Displays variations of loading skeleton placeholders with different row counts and padding configurations.
  """

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.LoadingState.loading_skeleton/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :basic_skeletons,
        variations: [
          %Variation{
            id: :default_rows,
            attributes: %{rows: 3}
          },
          %Variation{
            id: :many_rows,
            attributes: %{rows: 5}
          },
          %Variation{
            id: :single_row,
            attributes: %{rows: 1}
          }
        ]
      },
      %VariationGroup{
        id: :with_padding,
        variations: [
          %Variation{
            id: :padded,
            attributes: %{rows: 3, class: "p-6 bg-gray-100 rounded-lg"}
          },
          %Variation{
            id: :compact,
            attributes: %{rows: 2, class: "p-2"}
          }
        ]
      }
    ]
  end
end
