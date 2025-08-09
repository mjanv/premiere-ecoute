defmodule PremiereEcouteWeb.Components.Card do
  @moduledoc """
  Card components for consistent container styling.
  """
  use Phoenix.Component

  @doc """
  Renders a card container with consistent styling.

  ## Examples

      <.card>
        <p>Card content goes here</p>
      </.card>

      <.card variant="primary" class="mb-4">
        <h3>Primary card with custom margin</h3>
      </.card>
  """
  attr :variant, :string, default: "default", values: ~w(default primary success warning danger)
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border",
      variant_classes(@variant),
      @class
    ]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # AIDEV-NOTE: Card variant helper function for consistent styling using design system colors
  defp variant_classes(variant) do
    case variant do
      "default" -> "bg-surface-elevated border-surface text-surface-primary"
      "primary" -> "bg-gradient-to-br from-blue-50/6 to-blue-100/3 border-white/10 text-surface-primary"
      "success" -> "bg-gradient-to-br from-green-50/6 to-green-100/3 border-white/10 text-surface-primary"
      "warning" -> "bg-gradient-to-br from-amber-50/6 to-amber-100/3 border-white/10 text-surface-primary"
      "danger" -> "bg-gradient-to-br from-red-50/6 to-red-100/3 border-white/10 text-surface-primary"
    end
  end
end