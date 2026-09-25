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
  @spec card(map()) :: Phoenix.LiveView.Rendered.t()
  attr :variant, :string, default: "default", values: ~w(default primary success warning danger)
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      class={[
        "rounded-lg border",
        variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp variant_classes(variant) do
    case variant do
      "default" -> "bg-surface-elevated border-surface text-surface-primary"
      "primary" -> "bg-gradient-to-br from-purple-500/15 to-pink-500/5 border-purple-400/30 text-surface-primary"
      "success" -> "bg-gradient-to-br from-green-500/15 to-emerald-500/5 border-green-400/30 text-surface-primary"
      "warning" -> "bg-gradient-to-br from-amber-500/15 to-orange-500/5 border-amber-400/30 text-surface-primary"
      "danger" -> "bg-gradient-to-br from-red-500/15 to-pink-500/5 border-red-400/30 text-surface-primary"
    end
  end
end
