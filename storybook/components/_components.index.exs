defmodule Storybook.Components do
  @moduledoc """
  Storybook index for application components.

  Organizes custom application components in the storybook with folder configuration.
  """

  use PhoenixStorybook.Index

  @spec folder_name() :: String.t()
  def folder_name, do: "Components"

  @spec folder_index() :: integer()
  def folder_index, do: 1

  @spec folder_open?() :: boolean()
  def folder_open?, do: true
end
