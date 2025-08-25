defmodule PremiereEcouteWeb.Components.PageHeader do
  @moduledoc """
  Renders a consistent page header with title, subtitle, and optional action buttons.

  ## AIDEV-NOTE: Reusable header component for My Sessions, My Billboards, My Library pages
  """
  use Phoenix.Component

  @doc """
  Renders a page header with title, subtitle and optional action buttons.

  ## Examples

      <.page_header 
        title="My Sessions"
        subtitle="Manage your listening sessions and track your music discoveries"
      />

      <.page_header
        title="My Billboards"
        subtitle="Manage your music billboard campaigns and collect playlist submissions"
      >
        <:action>
          <.link navigate={~p"/billboards/new"} class="...">New Billboard</.link>
        </:action>
      </.page_header>
  """
  attr :title, :string, required: true, doc: "The main page title"
  attr :subtitle, :string, default: nil, doc: "Optional subtitle description"
  attr :class, :string, default: "mb-8", doc: "Additional CSS classes"

  slot :action, doc: "Optional action buttons or links"

  def page_header(assigns) do
    ~H"""
    <div class={@class}>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-4xl font-bold text-white mb-2">{@title}</h1>
          <p :if={@subtitle} class="text-slate-300/90 text-lg">
            {@subtitle}
          </p>
        </div>

        <div :if={@action != []} class="flex items-center space-x-3">
          {render_slot(@action)}
        </div>
      </div>
    </div>
    """
  end
end
