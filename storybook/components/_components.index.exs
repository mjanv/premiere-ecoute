defmodule Storybook.Components do
  @moduledoc """
  Storybook index for application components.

  Organizes custom application components in the storybook with folder configuration.
  """

  use PhoenixStorybook.Index

  def folder_name, do: "Components"
  def folder_index, do: 1
  def folder_open?, do: true
end
