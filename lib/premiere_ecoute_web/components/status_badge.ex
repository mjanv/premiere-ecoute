defmodule PremiereEcouteWeb.Components.StatusBadge do
  @moduledoc """
  Status badge components for consistent status indicators across the application.
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
    # Determine the final variant to use (variant overrides status)
    final_variant = assigns.variant || status_to_variant(assigns.status)

    icon_classes =
      [
        "flex-shrink-0",
        size_icon_classes(assigns.size),
        assigns.inner_block != [] && size_icon_spacing_classes(assigns.size)
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    assigns = assign(assigns, :final_variant, final_variant)
    assigns = assign(assigns, :icon_classes, icon_classes)

    ~H"""
    <span
      class={[
        "inline-flex items-center rounded-full font-medium border",
        size_classes(@size),
        variant_classes(@final_variant),
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
        {status_text(@status)}
      <% end %>
    </span>
    """
  end

  @doc """
  Renders a status badge specifically for listening session status.

  ## Examples

      <.session_status_badge status={:preparing} />
      <.session_status_badge status={:active} size="lg" />
  """
  attr :status, :atom, required: true, doc: "Session status atom (:preparing, :active, :stopped, :completed)"
  attr :size, :string, default: "md", values: ~w(xs sm md lg), doc: "Size variant"
  attr :class, :string, default: nil
  attr :rest, :global

  def session_status_badge(assigns) do
    # Convert atom status to string for the base status_badge component
    status_string = atom_to_status_string(assigns.status)
    assigns = assign(assigns, :status_string, status_string)

    ~H"""
    <.status_badge status={@status_string} size={@size} class={@class} {@rest} />
    """
  end

  # AIDEV-NOTE: Convert session status atoms to badge status strings
  defp atom_to_status_string(status) do
    case status do
      :preparing -> "preparing"
      :active -> "active"
      :stopped -> "stopped"
      :completed -> "completed"
      _ -> "info"
    end
  end

  # AIDEV-NOTE: Convert session status to badge variant
  defp status_to_variant(status) do
    case status do
      "active" -> "success"
      "preparing" -> "warning"
      "completed" -> "info"
      "stopped" -> "secondary"
      _ -> "secondary"
    end
  end

  # AIDEV-NOTE: Get display text for predefined statuses
  defp status_text(status) do
    case status do
      "active" -> "Active"
      "preparing" -> "Preparing"
      "completed" -> "Completed"
      "stopped" -> "Stopped"
      "success" -> "Success"
      "warning" -> "Warning"
      "error" -> "Error"
      "info" -> "Info"
      _ -> ""
    end
  end

  # AIDEV-NOTE: Size helper functions for consistent badge sizing
  defp size_classes(size) do
    case size do
      "xs" -> "px-2 py-0.5 text-xs"
      "sm" -> "px-2.5 py-1 text-xs"
      "md" -> "px-3 py-1 text-sm"
      "lg" -> "px-4 py-1.5 text-base"
    end
  end

  defp size_icon_classes(size) do
    case size do
      "xs" -> "w-3 h-3"
      "sm" -> "w-3 h-3"
      "md" -> "w-4 h-4"
      "lg" -> "w-5 h-5"
    end
  end

  defp size_icon_spacing_classes(size) do
    case size do
      "xs" -> "mr-1"
      "sm" -> "mr-1"
      "md" -> "mr-1.5"
      "lg" -> "mr-2"
    end
  end

  # AIDEV-NOTE: Variant color schemes using design system colors
  defp variant_classes(variant) do
    case variant do
      "success" -> "bg-green-600/15 text-green-300 border-green-600/25"
      "warning" -> "bg-yellow-600/15 text-yellow-300 border-yellow-600/25"
      "error" -> "bg-red-600/15 text-red-300 border-red-600/25"
      "info" -> "bg-blue-600/15 text-blue-300 border-blue-600/25"
      "primary" -> "bg-purple-600/15 text-purple-300 border-purple-600/25"
      "secondary" -> "bg-surface-interactive/50 text-surface-muted border-surface"
      _ -> "bg-surface-interactive/50 text-surface-muted border-surface"
    end
  end
end
