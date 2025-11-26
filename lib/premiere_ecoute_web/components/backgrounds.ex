defmodule PremiereEcouteWeb.Components.Backgrounds do
  @moduledoc """
  Background components.

  Provides gradient background components with conditional rendering based on status values.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :status, :any, default: nil
  attr :statutes, :list, default: []
  slot :inner_block, required: true

  def gradient_bg(assigns) do
    ~H"""
    <%= if is_nil(@status) or @status in @statutes do %>
      <div class={[
        "rounded-xl bg-gradient-to-br from-purple-900/80 to-pink-900/80",
        @class
      ]}>
        {render_slot(@inner_block)}
      </div>
    <% end %>
    """
  end
end
