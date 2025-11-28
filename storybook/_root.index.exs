defmodule Storybook.Root do
  @moduledoc """
  Storybook root index.

  Configures the root level storybook navigation with folder icons and entry points.
  """

  use PhoenixStorybook.Index

  @spec folder_icon() :: {atom(), String.t(), atom(), String.t()}
  def folder_icon, do: {:fa, "book-open", :light, "psb:mr-1"}

  @spec folder_name() :: String.t()
  def folder_name, do: "Storybook"

  @spec folder_index() :: integer()
  def folder_index, do: 0

  @spec entry(String.t()) :: keyword()
  def entry("index") do
    [
      name: "Welcome Page",
      icon: {:fa, "hand-wave", :thin}
    ]
  end
end
