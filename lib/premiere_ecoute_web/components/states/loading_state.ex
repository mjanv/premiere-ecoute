defmodule PremiereEcouteWeb.Components.LoadingState do
  @moduledoc """
  Loading state components with skeleton placeholders for consistent loading experiences.
  """

  use Phoenix.Component

  @doc """
  Renders a loading skeleton with customizable elements.

  ## Examples

      <.loading_skeleton />

      <.loading_skeleton rows={3} class="p-4" />

      <.loading_skeleton>
        <.skeleton_element type="title" />
        <.skeleton_element type="text" width="3/4" />
        <.skeleton_element type="avatar" />
      </.loading_skeleton>
  """
  @spec loading_skeleton(map()) :: Phoenix.LiveView.Rendered.t()
  attr :rows, :integer, default: 3, doc: "Number of skeleton rows to display"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, doc: "Custom skeleton elements (overrides default rows)"

  def loading_skeleton(assigns) do
    ~H"""
    <div
      class={[
        "animate-pulse space-y-3",
        @class
      ]}
      {@rest}
    >
      <%= if @inner_block != [] do %>
        {render_slot(@inner_block)}
      <% else %>
        <%= for _ <- 1..@rows do %>
          <.skeleton_element type="text" />
        <% end %>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders individual skeleton elements.

  ## Examples

      <.skeleton_element type="title" />
      <.skeleton_element type="text" width="1/2" />
      <.skeleton_element type="avatar" size="lg" />
      <.skeleton_element type="card" height="20" />
  """
  @spec skeleton_element(map()) :: Phoenix.LiveView.Rendered.t()
  attr :type, :string, default: "text", values: ~w(text title avatar button card image), doc: "Type of skeleton element"
  attr :width, :string, default: "full", doc: "Width class (e.g., '1/2', '3/4', 'full')"
  attr :height, :string, default: nil, doc: "Height in rem units or Tailwind class"
  attr :size, :string, default: "md", values: ~w(xs sm md lg xl), doc: "Size variant for specific types"
  attr :class, :string, default: nil
  attr :rest, :global

  def skeleton_element(assigns) do
    ~H"""
    <div
      class={[
        "bg-surface-card rounded",
        element_classes(@type, @size, @width, @height),
        @class
      ]}
      {@rest}
    >
    </div>
    """
  end

  @doc """
  Renders a loading state for lists/grids with multiple skeleton items.

  ## Examples

      <.loading_list count={5} />

      <.loading_list count={3} class="grid grid-cols-2 gap-4">
        <:item>
          <.skeleton_element type="image" height="32" />
          <.skeleton_element type="title" />
          <.skeleton_element type="text" width="2/3" />
        </:item>
      </.loading_list>
  """
  @spec loading_list(map()) :: Phoenix.LiveView.Rendered.t()
  attr :count, :integer, default: 3, doc: "Number of skeleton items"
  attr :class, :string, default: "space-y-4"
  attr :rest, :global

  slot :item, doc: "Custom skeleton item content"

  def loading_list(assigns) do
    ~H"""
    <div class={[@class]} {@rest}>
      <%= for _ <- 1..@count do %>
        <div class="space-y-3">
          <%= if @item != [] do %>
            {render_slot(@item)}
          <% else %>
            <.skeleton_element type="title" width="1/3" />
            <.skeleton_element type="text" />
            <.skeleton_element type="text" width="3/4" />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a loading spinner for inline loading states.

  ## Examples

      <.loading_spinner />
      <.loading_spinner size="sm" class="text-blue-500" />
  """
  @spec loading_spinner(map()) :: Phoenix.LiveView.Rendered.t()
  attr :size, :string, default: "md", values: ~w(xs sm md lg xl)
  attr :class, :string, default: "text-surface-muted"
  attr :rest, :global

  def loading_spinner(assigns) do
    ~H"""
    <div
      class={[
        "animate-spin rounded-full border-2 border-current border-t-transparent",
        spinner_size_classes(@size),
        @class
      ]}
      {@rest}
    >
    </div>
    """
  end

  defp element_classes(type, size, width, height) do
    base_classes =
      case type do
        "text" -> ["h-4"]
        "title" -> ["h-6", "font-semibold"]
        "avatar" -> ["rounded-full"] ++ avatar_size_classes(size)
        "button" -> ["h-10", "px-4", "rounded-lg"]
        "card" -> ["p-6", height_class(height) || "h-24"]
        "image" -> ["rounded-lg", height_class(height) || "h-48"]
        _ -> ["h-4"]
      end

    width_class =
      case width do
        "full" -> "w-full"
        w when is_binary(w) -> "w-#{w}"
        _ -> "w-full"
      end

    base_classes ++ [width_class]
  end

  defp avatar_size_classes(size) do
    case size do
      "xs" -> ["w-6", "h-6"]
      "sm" -> ["w-8", "h-8"]
      "md" -> ["w-12", "h-12"]
      "lg" -> ["w-16", "h-16"]
      "xl" -> ["w-20", "h-20"]
    end
  end

  defp height_class(nil), do: nil

  defp height_class(height) when is_binary(height) do
    if String.contains?(height, ["h-", "min-h-", "max-h-"]) do
      height
    else
      "h-#{height}"
    end
  end

  defp spinner_size_classes(size) do
    case size do
      "xs" -> "w-3 h-3"
      "sm" -> "w-4 h-4"
      "md" -> "w-6 h-6"
      "lg" -> "w-8 h-8"
      "xl" -> "w-12 h-12"
    end
  end

  @doc """
  Renders a loading overlay for full-screen or modal loading states.

  ## Examples

      <.loading_overlay message="Loading..." />
      <.loading_overlay variant="overlay" message="Searching albums..." />
  """
  @spec loading_overlay(map()) :: Phoenix.LiveView.Rendered.t()
  attr :message, :string, default: "Loading..."
  attr :variant, :string, default: "modal", values: ~w(modal overlay), doc: "Overlay style variant"
  attr :class, :string, default: nil
  attr :rest, :global

  def loading_overlay(assigns) do
    ~H"""
    <div
      class={[
        overlay_base_classes(@variant),
        @class
      ]}
      {@rest}
    >
      <div class="flex flex-col items-center justify-center space-y-4">
        <.loading_spinner size="lg" class="text-purple-400" />
        <p class="text-surface-primary text-lg font-medium">{@message}</p>
      </div>
    </div>
    """
  end

  defp overlay_base_classes(variant) do
    case variant do
      "modal" -> "fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      "overlay" -> "absolute inset-0 bg-surface/90 backdrop-blur-sm flex items-center justify-center z-40"
    end
  end
end
