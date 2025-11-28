defmodule Storybook.CoreComponents do
  @moduledoc """
  Storybook index for core components.

  Organizes core UI components in the storybook with custom icons and folder configuration.
  """

  use PhoenixStorybook.Index

  @spec folder_open?() :: boolean()
  def folder_open?, do: true

  @spec folder_index() :: integer()
  def folder_index, do: 1

  @spec entry(String.t()) :: keyword()
  def entry("back"), do: [icon: {:fa, "circle-left", :thin}]
  def entry("button"), do: [icon: {:fa, "rectangle-ad", :thin}]
  def entry("error"), do: [icon: {:fa, "circle-exclamation", :thin}]
  def entry("flash"), do: [icon: {:fa, "bolt", :thin}]
  def entry("header"), do: [icon: {:fa, "heading", :thin}]
  def entry("icon"), do: [icon: {:fa, "icons", :thin}]
  def entry("input"), do: [icon: {:fa, "input-text", :thin}]
  def entry("list"), do: [icon: {:fa, "list", :thin}]
  def entry("table"), do: [icon: {:fa, "table", :thin}]
end
