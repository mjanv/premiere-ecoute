defmodule PremiereEcouteWeb.Components.ActivityCard do
  @moduledoc """
  Renders activity cards used on the home dashboard for displaying user activities,
  creating new content, or showing unavailable features.
  """

  use Phoenix.Component

  @doc """
  Renders an activity card for dashboard content.

  ## Examples

      <!-- Content card with existing data -->
      <.activity_card
        type="content"
        label="Active Session"
        title="Abbey Road"
        subtitle="by The Beatles"
        status_text="Live"
        status_variant="success"
        action_text="Continue session"
        navigate={~p"/sessions/123"}
      >
        <:icon>
          <img src="cover.jpg" class="w-16 h-16 rounded-lg" />
        </:icon>
      </.activity_card>

      <!-- Action card for creating new content -->
      <.activity_card
        type="action"
        label="Create Session"
        title="Start Listening Session"
        subtitle="Share music with your community"
        status_text="New"
        status_variant="info"
        action_text="Choose an album to get started"
        navigate={~p"/sessions/new"}
      />

      <!-- Disabled card -->
      <.activity_card
        type="disabled"
        title="Sessions not available"
      />
  """
  attr :type, :string, required: true, values: ~w(content action disabled), doc: "Card type"
  attr :label, :string, default: nil, doc: "Card label/category"
  attr :title, :string, required: true, doc: "Main title"
  attr :subtitle, :string, default: nil, doc: "Subtitle text"
  attr :status_text, :string, default: nil, doc: "Status badge text"

  attr :status_variant, :string,
    default: "default",
    values: ~w(success warning info danger default),
    doc: "Status badge color variant"

  attr :action_text, :string, default: nil, doc: "Action/CTA text"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :rest, :global

  slot :icon, doc: "Custom icon content (image, svg, etc.)"

  def activity_card(assigns) do
    ~H"""
    <div class={["w-1/2", @class]}>
      <%= if @type == "disabled" do %>
        <div class="p-6 bg-slate-800/30 border border-slate-700/30 rounded-xl h-full flex items-center justify-center">
          <div class="text-center">
            <div class="w-12 h-12 bg-slate-700/50 rounded-lg flex items-center justify-center mx-auto mb-3">
              <svg class="w-6 h-6 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
                />
              </svg>
            </div>
            <p class="text-sm text-slate-500">{@title}</p>
          </div>
        </div>
      <% else %>
        <.link class="block group h-full" {@rest}>
          <.activity_card_content {assigns} />
        </.link>
      <% end %>
    </div>
    """
  end

  defp activity_card_content(assigns) do
    ~H"""
    <div class={[
      "p-6 border border-white/10 rounded-xl hover:shadow-xl transition-all duration-300 hover:scale-[1.02] backdrop-blur-sm h-full flex flex-col",
      card_background_class(@type)
    ]}>
      <div class="flex items-center justify-between mb-4">
        <h2 :if={@label} class="text-base font-medium text-slate-400">{@label}</h2>
        <span
          :if={@status_text}
          class={[
            "inline-flex items-center px-3 py-1 rounded text-sm",
            status_class(@status_variant)
          ]}
        >
          {@status_text}
        </span>
      </div>

      <div class="flex items-center gap-4 mb-4 flex-1">
        <div class="flex-shrink-0">
          <%= if @icon != [] do %>
            {render_slot(@icon)}
          <% else %>
            <div class={[
              "w-16 h-16 rounded-lg flex items-center justify-center",
              default_icon_background_class(@type)
            ]}>
              <svg class={["w-8 h-8", default_icon_color_class(@type)]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= if @type == "action" do %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                  />
                <% else %>
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
                  />
                <% end %>
              </svg>
            </div>
          <% end %>
        </div>

        <div class="flex-1 min-w-0">
          <h3 class="text-xl font-semibold text-white mb-1 group-hover:text-slate-200 transition-colors truncate">
            {@title}
          </h3>
          <p :if={@subtitle} class="text-base text-slate-400 truncate">
            {@subtitle}
          </p>
        </div>
      </div>

      <div :if={@action_text} class="flex items-center gap-2 text-slate-500 group-hover:text-slate-400 transition-colors mt-auto">
        <span class="text-sm">
          {@action_text}
        </span>
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </div>
    </div>
    """
  end

  defp card_background_class("content"), do: "bg-gradient-to-br from-slate-50/6 to-slate-100/3"
  defp card_background_class("action"), do: "bg-gradient-to-br from-indigo-50/6 to-blue-100/3"

  defp default_icon_background_class("content"), do: "bg-slate-700/50"
  defp default_icon_background_class("action"), do: "bg-gradient-to-br from-indigo-600/30 to-blue-700/20"

  defp default_icon_color_class("content"), do: "text-slate-400"
  defp default_icon_color_class("action"), do: "text-indigo-400"

  defp status_class("success"), do: "bg-green-600/20 text-green-400"
  defp status_class("warning"), do: "bg-amber-600/20 text-amber-400"
  defp status_class("info"), do: "bg-blue-600/20 text-blue-400"
  defp status_class("danger"), do: "bg-red-600/20 text-red-400"
  defp status_class("default"), do: "bg-indigo-600/20 text-indigo-400"
end
