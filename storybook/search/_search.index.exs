defmodule Storybook.CoreComponents do
  use PhoenixStorybook.Index

  def folder_open?, do: false
  def folder_index, do: 2

  def entry("searchbar"), do: [icon: {:fa, "circle-left", :thin}]
end
