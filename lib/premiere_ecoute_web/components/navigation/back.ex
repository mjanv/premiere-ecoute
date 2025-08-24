defmodule PremiereEcouteWeb.Components.Navigation.Back do
  @moduledoc false

  use Phoenix.Component

  attr :href, :string, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mb-8">
      <.link
        href={@href}
        class="inline-flex items-center text-slate-500 hover:text-slate-400 transition-colors text-sm mb-4"
      >
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M15 19l-7-7 7-7"
          />
        </svg>
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end
end
