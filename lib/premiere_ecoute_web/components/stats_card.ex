defmodule PremiereEcouteWeb.Components.StatsCard do
  @moduledoc """
  Statistics card component for dashboard displays.
  """
  use Phoenix.Component

  alias PremiereEcouteWeb.Components.Card
  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders a statistics card with icon, value, and label.

  ## Examples

      <.stats_card icon="hero-users" value="1,234" label="Total Users" color="blue" />

      <.stats_card icon="hero-chart-bar" value="87%" label="Success Rate" color="green" navigate={~p"/admin/stats"} />
  """
  attr :icon, :string, required: true, doc: "Heroicon name for the stats icon"
  attr :value, :string, required: true, doc: "The main statistic value to display"
  attr :label, :string, required: true, doc: "The label describing the statistic"

  attr :color, :string,
    default: "blue",
    values: ~w(blue green yellow purple orange red gray),
    doc: "Color theme for the icon background"

  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(href navigate patch method phx-click)

  def stats_card(assigns) do
    assigns =
      assign(assigns, :card_classes, [
        "p-8 hover-surface-elevated transition-colors",
        (assigns.rest[:navigate] || assigns.rest[:href] || assigns.rest[:patch] || assigns.rest["phx-click"]) && "cursor-pointer",
        assigns.class
      ])

    # AIDEV-NOTE: Extract navigation attributes from rest
    {nav_attrs, rest_attrs} =
      Map.split(assigns.rest, [:navigate, :href, :patch, :method, :"phx-click"])

    assigns =
      assigns
      |> assign(:nav_attrs, nav_attrs)
      |> assign(:rest_attrs, rest_attrs)
      |> assign(:has_navigation, nav_attrs != %{})

    ~H"""
    <%= if @has_navigation do %>
      <.link {@nav_attrs}>
        <Card.card class={@card_classes} {@rest_attrs}>
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class={[
                "w-12 h-12 rounded-lg flex items-center justify-center",
                icon_color_classes(@color)
              ]}>
                <CoreComponents.icon name={@icon} class="w-7 h-7 text-white" />
              </div>
            </div>
            <div class="ml-6">
              <div class="text-4xl font-bold text-surface-primary">{@value}</div>
              <div class="text-lg text-surface-muted">{@label}</div>
            </div>
          </div>
        </Card.card>
      </.link>
    <% else %>
      <Card.card class={@card_classes} {@rest_attrs}>
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class={[
              "w-12 h-12 rounded-lg flex items-center justify-center",
              icon_color_classes(@color)
            ]}>
              <CoreComponents.icon name={@icon} class="w-7 h-7 text-white" />
            </div>
          </div>
          <div class="ml-6">
            <div class="text-4xl font-bold text-surface-primary">{@value}</div>
            <div class="text-lg text-surface-muted">{@label}</div>
          </div>
        </div>
      </Card.card>
    <% end %>
    """
  end

  # AIDEV-NOTE: Icon color helper function for stats cards
  defp icon_color_classes(color) do
    case color do
      "blue" -> "bg-blue-500"
      "green" -> "bg-green-500"
      "yellow" -> "bg-yellow-500"
      "purple" -> "bg-purple-500"
      "orange" -> "bg-orange-500"
      "red" -> "bg-red-500"
      "gray" -> "bg-gray-500"
    end
  end
end
