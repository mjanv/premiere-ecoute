defmodule PremiereEcouteWeb.Components.StatusBadge do
  @moduledoc """
  Status badge components
  """

  use Phoenix.Component

  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders a status badge with consistent styling.

  ## Examples

      <.status_badge status="active" />

      <.status_badge status="warning" size="sm">
        Custom content
      </.status_badge>

      <.status_badge variant="success" icon="hero-check-circle" size="lg">
        Completed
      </.status_badge>
  """
  attr :status, :string,
    default: "info",
    values: ~w(active preparing completed stopped success warning error info),
    doc: "Predefined status type"

  attr :variant, :string,
    default: nil,
    doc: "Custom variant (overrides status) - success, warning, error, info, primary, secondary"

  attr :icon, :string, default: nil, doc: "Heroicon name to display"
  attr :size, :string, default: "md", values: ~w(xs sm md lg), doc: "Size variant"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, doc: "Badge content (overrides predefined status text)"

  def status_badge(assigns) do
    variant = assigns.variant || status_to_variant(assigns.status)

    icon_classes =
      [
        "flex-shrink-0",
        icon_size(assigns.size),
        assigns.inner_block != [] && icon_spacing(assigns.size)
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    assigns =
      assigns
      |> assign(:status, to_string(assigns.status))
      |> assign(:variant, variant)
      |> assign(:icon_classes, icon_classes)

    ~H"""
    <span
      class={[
        "inline-flex items-center rounded-full font-medium border",
        size(@size),
        variant(@variant),
        @class
      ]}
      {@rest}
    >
      <%= if @icon do %>
        <CoreComponents.icon name={@icon} class={@icon_classes} />
      <% end %>

      <%= if @inner_block != [] do %>
        {render_slot(@inner_block)}
      <% else %>
        {String.capitalize(@status)}
      <% end %>
    </span>
    """
  end

  defp status_to_variant(status) do
    case to_string(status) do
      "active" -> "success"
      "preparing" -> "warning"
      "completed" -> "info"
      _ -> "secondary"
    end
  end

  defp size("xs"), do: "px-2 py-0.5 text-xs"
  defp size("sm"), do: "px-2.5 py-1 text-xs"
  defp size("md"), do: "px-3 py-1 text-sm"
  defp size("lg"), do: "px-4 py-1.5 text-base"

  defp icon_size("xs"), do: "w-3 h-3"
  defp icon_size("sm"), do: "w-3 h-3"
  defp icon_size("md"), do: "w-4 h-4"
  defp icon_size("lg"), do: "w-5 h-5"

  defp icon_spacing("xs"), do: "mr-1"
  defp icon_spacing("sm"), do: "mr-1"
  defp icon_spacing("md"), do: "mr-1.5"
  defp icon_spacing("lg"), do: "mr-2"

  defp variant("success"), do: "bg-green-600/15 text-green-300 border-green-600/25"
  defp variant("warning"), do: "bg-yellow-600/15 text-yellow-300 border-yellow-600/25"
  defp variant("error"), do: "bg-red-600/15 text-red-300 border-red-600/25"
  defp variant("info"), do: "bg-blue-600/15 text-blue-300 border-blue-600/25"
  defp variant("primary"), do: "bg-purple-600/15 text-purple-300 border-purple-600/25"
  defp variant("secondary"), do: "bg-surface-interactive/50 text-surface-muted border-surface"
  defp variant(_), do: "bg-surface-interactive/50 text-surface-muted border-surface"
end
