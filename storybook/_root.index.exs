defmodule Storybook.Root do
  @moduledoc """
  Storybook root index.

  Configures the root level storybook navigation with folder icons and entry points.
  """

  use PhoenixStorybook.Index

  def folder_icon, do: {:fa, "book-open", :light, "psb:mr-1"}
  def folder_name, do: "Storybook"
  def folder_index, do: 0

  def entry("index") do
    [
      name: "Welcome Page",
      icon: {:fa, "hand-wave", :thin}
    ]
  end
end
