defmodule PremiereEcouteWeb.Components.Drawer do
  @moduledoc """
  Drawer component — a panel that slides in from the right, overlaying content
  without pushing it. Closes on backdrop click or the built-in ✕ button.

  Animations are driven by a Motion.js hook (`SidePanel` hook in JS). Show/hide
  use `JS` commands so no server round-trip is needed.

  ## Examples

      <.drawer id="wiki-drawer">
        <:header>Wikipedia</:header>
        <p>Content…</p>
        <:footer>
          <button>Save</button>
        </:footer>
      </.drawer>

      <button phx-click={show_drawer("wiki-drawer")}>Open</button>
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias PremiereEcouteWeb.CoreComponents

  attr :id, :string, required: true
  attr :on_cancel, JS, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header, required: true, doc: "Drawer title / header content"
  slot :inner_block, required: true, doc: "Scrollable body content"
  slot :footer, doc: "Optional sticky footer (e.g. action buttons)"

  @spec drawer(map()) :: Phoenix.LiveView.Rendered.t()
  def drawer(assigns) do
    assigns = assign(assigns, :on_cancel, assigns.on_cancel || hide_drawer(assigns.id))

    ~H"""
    <%!-- Backdrop --%>
    <div
      id={"#{@id}-backdrop"}
      class="hidden fixed inset-0 z-40"
      style="background-color: rgba(2, 6, 23, 0.7);"
      aria-hidden="true"
      phx-click={@on_cancel}
    />

    <%!-- Drawer panel --%>
    <div
      id={@id}
      class={["hidden fixed top-0 right-0 h-full w-full sm:w-[480px] z-50 flex flex-col", @class]}
      style="background-color: var(--color-dark-900); border-left: 1px solid var(--color-dark-800);"
      role="dialog"
      aria-modal="true"
      phx-hook="Drawer"
      {@rest}
    >
      <%!-- Header --%>
      <div
        class="flex items-center justify-between px-6 py-4 shrink-0"
        style="border-bottom: 1px solid var(--color-dark-800);"
      >
        <div class="font-semibold text-white text-base leading-tight">
          {render_slot(@header)}
        </div>
        <button
          type="button"
          phx-click={@on_cancel}
          class="ml-4 shrink-0 text-gray-500 hover:text-gray-300 transition-colors"
          aria-label="Close"
        >
          <CoreComponents.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>

      <%!-- Scrollable body --%>
      <div class="flex-1 overflow-y-auto px-6 py-5 text-gray-300">
        {render_slot(@inner_block)}
      </div>

      <%!-- Optional sticky footer --%>
      <%= if @footer != [] do %>
        <div
          class="shrink-0 px-6 py-4 flex items-center justify-end gap-3"
          style="border-top: 1px solid var(--color-dark-800);"
        >
          {render_slot(@footer)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc "Shows the drawer with a slide-in animation."
  @spec show_drawer(JS.t(), String.t()) :: JS.t()
  def show_drawer(js \\ %JS{}, id) when is_binary(id) do
    JS.dispatch(js, "drawer:open", to: "##{id}")
  end

  @doc "Hides the drawer with a slide-out animation."
  @spec hide_drawer(JS.t(), String.t()) :: JS.t()
  def hide_drawer(js \\ %JS{}, id) when is_binary(id) do
    JS.dispatch(js, "drawer:close", to: "##{id}")
  end
end
