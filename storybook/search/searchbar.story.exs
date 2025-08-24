defmodule Storybook.Search.SearchBar do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.Search.searchbar/1

  def render_source, do: :function

  def variations,
    do: [
      %Variation{
        id: :default,
        attributes: %{
          query: nil,
          placeholder: "Placeholder"
        }
      }
    ]
end
