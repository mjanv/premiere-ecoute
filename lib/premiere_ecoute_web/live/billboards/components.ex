defmodule PremiereEcouteWeb.Billboards.Components do
  @moduledoc """
  Billboard UI components.

  Provides synthwave-themed Phoenix components including ASCII art billboard header, tab navigation with active state styling, and podium display for top 3 ranked entries with clickable interactions.
  """

  use Phoenix.Component

  @doc """
  Renders ASCII art billboard header with optional title.

  Displays a colorful ASCII art "BILLBOARD" text in synthwave gradient colors with optional subtitle text below.
  """
  @spec billboard(map()) :: Phoenix.LiveView.Rendered.t()
  attr :title, :string, required: false, default: nil

  def billboard(assigns) do
    ~H"""
    <pre class="ascii-art text-sm sm:text-lg md:text-xl lg:text-2xl mb-2 inline-block font-mono synthwave-title">
      <span class="text-red-500">██████╗ ██╗██╗     ██╗     ██████╗  ██████╗  █████╗ ██████╗ ██████╗</span>
      <span class="text-orange-500">██╔══██╗██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗</span>
      <span class="text-yellow-500">██████╔╝██║██║     ██║     ██████╔╝██║   ██║███████║██████╔╝██║  ██║</span>
      <span class="text-green-500">██╔══██╗██║██║     ██║     ██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║</span>
      <span class="text-blue-500">██████╔╝██║███████╗███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝</span>
      <span class="text-purple-500">╚═════╝ ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝</span>
    </pre>

    <%= if @title do %>
      <div class="mt-6 mb-4">
        <h2 class="text-2xl md:text-3xl font-mono font-bold text-transparent bg-clip-text bg-gradient-to-r from-pink-500 via-purple-500 to-cyan-500 synthwave-title">
          {@title}
        </h2>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a tab button with active state styling.

  Displays a mode-switching tab button with purple theme and active border highlight for billboard navigation.
  """
  @spec tab(map()) :: Phoenix.LiveView.Rendered.t()
  attr :active, :atom, required: true
  attr :mode, :string, required: true
  slot :inner_block

  def tab(assigns) do
    ~H"""
    <button
      phx-click="switch_mode"
      phx-value-mode={@mode}
      class={"px-6 py-3 font-mono font-bold transition-colors duration-200 #{if @active == String.to_atom(@mode), do: "bg-purple-600 text-white border-b-2 border-purple-300", else: "text-purple-400 hover:text-purple-300"}"}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a container for tab buttons.

  Displays a horizontal tab bar with purple border styling for organizing multiple tab components.
  """
  @spec tabs(map()) :: Phoenix.LiveView.Rendered.t()
  slot :inner_block

  def tabs(assigns) do
    ~H"""
    <div class="flex mb-8 space-x-2 border-b border-purple-500">
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a podium display for top 3 entries.

  Displays a three-tiered podium with gold, silver, and bronze styling showing top 3 ranked entries with emoji medals and clickable interactions.
  """
  @spec podium(map()) :: Phoenix.LiveView.Rendered.t()
  attr :action, :string, required: true
  attr :entries, :list, default: []
  slot :inner_block

  def podium(assigns) do
    ~H"""
    <div>
      <%= if length(@entries) >= 3 do %>
        <div class="flex justify-center items-end space-x-8 mb-12">
          <div class="text-center">
            <div class="bg-yellow-600 border-4 border-yellow-400 p-4 rounded-t-lg h-28 flex flex-col justify-end w-64">
              <div class="text-4xl mb-2">🥈</div>
              <div class="text-xl font-bold text-yellow-100">#2</div>
            </div>
            <div
              class="bg-yellow-700 p-4 text-center w-64 cursor-pointer hover:bg-yellow-600 transition-colors"
              phx-click={@action}
              phx-value-rank={2}
              phx-value-location="podium"
            >
              {render_slot(@inner_block, {Enum.at(@entries, 1), "text-lg", "text-yellow-100"})}
            </div>
          </div>

          <div class="text-center">
            <div class="bg-pink-600 border-4 border-pink-400 p-4 rounded-t-lg h-32 flex flex-col justify-end w-64">
              <div class="text-5xl mb-2">👑</div>
              <div class="text-2xl font-bold text-pink-100">#1</div>
            </div>
            <div
              class="bg-pink-700 p-4 text-center w-64 cursor-pointer hover:bg-pink-600 transition-colors"
              phx-click={@action}
              phx-value-rank={1}
              phx-value-location="podium"
            >
              {render_slot(@inner_block, {Enum.at(@entries, 0), "text-xl", "text-pink-100"})}
            </div>
          </div>

          <div class="text-center">
            <div class="bg-cyan-700 border-4 border-cyan-500 p-4 rounded-t-lg h-24 flex flex-col justify-end w-64">
              <div class="text-3xl mb-2">🥉</div>
              <div class="text-xl font-bold text-cyan-200">#3</div>
            </div>
            <div
              class="bg-cyan-800 p-4 text-center w-64 cursor-pointer hover:bg-cyan-700 transition-colors"
              phx-click={@action}
              phx-value-rank={3}
              phx-value-location="podium"
            >
              {render_slot(@inner_block, {Enum.at(@entries, 2), "text-lg", "text-cyan-100"})}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
