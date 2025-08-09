defmodule PremiereEcouteWeb.Components.EmptyState do
  @moduledoc """
  Empty state components for consistent empty data presentations.
  """
  use Phoenix.Component

  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders an empty state with icon, title, description, and optional action.

  ## Examples

      <.empty_state
        icon="hero-musical-note"
        title="No Albums Yet"
        description="You haven't added any albums to your library."
      />

      <.empty_state
        icon="hero-users"
        title="No Sessions"
        description="No listening sessions have been created yet."
      >
        <:action>
          <.link navigate="/sessions/new" class="btn btn-primary">
            Create Session
          </.link>
        </:action>
      </.empty_state>
  """
  attr :icon, :string, required: true, doc: "Heroicon name for the empty state"
  attr :title, :string, required: true, doc: "Main title for the empty state"
  attr :description, :string, required: true, doc: "Description text explaining the empty state"
  attr :size, :string, default: "md", values: ~w(sm md lg), doc: "Size variant"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :action, doc: "Optional action button or link"

  def empty_state(assigns) do
    icon_classes = [
      "text-surface-muted",
      size_icon_classes(assigns.size)
    ] |> Enum.join(" ")
    
    assigns = assign(assigns, :icon_classes, icon_classes)
    
    ~H"""
    <div class={[
      "text-center",
      size_padding_classes(@size),
      @class
    ]} {@rest}>
      <!-- Icon Container -->
      <div class={[
        "rounded-full flex items-center justify-center mx-auto mb-6 bg-surface-card",
        size_icon_container_classes(@size)
      ]}>
        <CoreComponents.icon name={@icon} class={@icon_classes} />
      </div>

      <!-- Content -->
      <h3 class={[
        "font-medium text-surface-bright mb-2",
        size_title_classes(@size)
      ]}>
        {@title}
      </h3>
      
      <p class={[
        "text-surface-muted mb-6",
        size_description_classes(@size)
      ]}>
        {@description}
      </p>

      <!-- Action -->
      <%= if @action != [] do %>
        <div class="flex justify-center">
          {render_slot(@action)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a simple empty state for lists/tables.

  ## Examples

      <.empty_list 
        message="No items found"
        icon="hero-inbox"
      />

      <.empty_list message="No results match your search">
        <:action>
          <button phx-click="clear_search" class="text-purple-400 hover:text-purple-300">
            Clear search
          </button>
        </:action>
      </.empty_list>
  """
  attr :message, :string, required: true, doc: "Empty list message"
  attr :icon, :string, default: "hero-inbox", doc: "Heroicon name"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :action, doc: "Optional action"

  def empty_list(assigns) do
    ~H"""
    <div class={[
      "text-center py-12",
      @class
    ]} {@rest}>
      <CoreComponents.icon name={@icon} class="w-12 h-12 text-surface-muted mx-auto mb-4" />
      <p class="text-surface-muted text-lg">{@message}</p>
      <%= if @action != [] do %>
        <div class="mt-4">
          {render_slot(@action)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an empty state specifically for search results.

  ## Examples

      <.empty_search 
        query="jazz albums"
        suggestions={["Try different keywords", "Check spelling"]}
      />
  """
  attr :query, :string, required: true, doc: "The search query that returned no results"
  attr :suggestions, :list, default: [], doc: "List of suggestion strings"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :action, doc: "Optional search action"

  def empty_search(assigns) do
    ~H"""
    <div class={[
      "text-center py-16",
      @class
    ]} {@rest}>
      <!-- Search Icon -->
      <div class="w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6 bg-surface-card">
        <CoreComponents.icon name="hero-magnifying-glass" class="w-10 h-10 text-surface-muted" />
      </div>

      <!-- Content -->
      <h3 class="text-xl font-medium text-surface-bright mb-2">
        No results found
      </h3>
      
      <p class="text-surface-muted mb-4">
        We couldn't find anything matching <span class="font-medium text-surface-primary">"{@query}"</span>
      </p>

      <!-- Suggestions -->
      <%= if @suggestions != [] do %>
        <div class="text-sm text-surface-muted mb-6">
          <p class="mb-2">Try:</p>
          <ul class="space-y-1">
            <%= for suggestion <- @suggestions do %>
              <li>• {suggestion}</li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <!-- Action -->
      <%= if @action != [] do %>
        <div class="flex justify-center">
          {render_slot(@action)}
        </div>
      <% end %>
    </div>
    """
  end

  # AIDEV-NOTE: Size helper functions for responsive empty states
  defp size_padding_classes(size) do
    case size do
      "sm" -> "py-8"
      "md" -> "py-16"
      "lg" -> "py-24"
    end
  end

  defp size_icon_container_classes(size) do
    case size do
      "sm" -> "w-16 h-16"
      "md" -> "w-24 h-24"
      "lg" -> "w-32 h-32"
    end
  end

  defp size_icon_classes(size) do
    case size do
      "sm" -> "w-8 h-8"
      "md" -> "w-12 h-12"
      "lg" -> "w-16 h-16"
    end
  end

  defp size_title_classes(size) do
    case size do
      "sm" -> "text-lg"
      "md" -> "text-xl"
      "lg" -> "text-2xl"
    end
  end

  defp size_description_classes(size) do
    case size do
      "sm" -> "text-sm"
      "md" -> "text-base"
      "lg" -> "text-lg"
    end
  end
end