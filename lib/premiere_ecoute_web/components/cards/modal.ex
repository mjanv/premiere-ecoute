defmodule PremiereEcouteWeb.Components.Modal do
  @moduledoc """
  Modal dialog components with consistent styling and behavior.

  Two variants:

  1. JS-state (default) — show/hide via JS commands, no server round-trip.
     Use `show_modal/1` and `hide_modal/1` to open/close.

  2. Server-state — controlled by a boolean assign, opened/closed via phx-click events.
     Use `<.modal show={@show_modal} on_cancel="close_modal">`.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders a modal dialog with backdrop and consistent styling.

  ## Examples

      <%!-- JS-state (no server round-trip) --%>
      <.modal id="my-modal">
        <:header>Title</:header>
        <p>Content</p>
        <:footer>
          <.button phx-click={hide_modal("my-modal")}>Close</.button>
        </:footer>
      </.modal>
      <.button phx-click={show_modal("my-modal")}>Open</.button>

      <%!-- Server-state --%>
      <%= if @show_modal do %>
        <.modal id="my-modal" show on_cancel="close_modal">
          <:header>Title</:header>
          <p>Content</p>
        </.modal>
      <% end %>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false, doc: "Server-state: render as visible (skip JS show/hide)"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name string to run on close"
  attr :size, :string, default: "md", values: ~w(sm md lg xl xxl full)
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header, doc: "Title rendered in the modal header bar"
  slot :inner_block, required: true, doc: "Modal body content"
  slot :footer, doc: "Action buttons rendered in the modal footer"

  @spec modal(map()) :: Phoenix.LiveView.Rendered.t()
  def modal(assigns) do
    assigns =
      assign(assigns,
        on_cancel: assigns.on_cancel || if(assigns.show, do: nil, else: hide_modal(assigns.id)),
        backdrop_class: if(assigns.show, do: "flex", else: "hidden")
      )

    ~H"""
    <div
      id={@id}
      class={[@backdrop_class, "fixed inset-0 items-center justify-center z-50 backdrop-blur-sm bg-black/50"]}
      {@rest}
    >
      <div
        id={"#{@id}-content"}
        class={[
          "bg-base-200 rounded-xl shadow-2xl mx-4 flex flex-col relative border border-neutral",
          modal_size_classes(@size),
          @class
        ]}
        phx-click-away={cancel_event(@on_cancel)}
      >
        <%!-- Header — always rendered so the close button is always present --%>
        <div class="flex items-center justify-between px-6 py-4 border-b border-neutral shrink-0">
          <div class="font-semibold text-base-content text-lg">
            {render_slot(@header)}
          </div>
          <button
            type="button"
            phx-click={cancel_event(@on_cancel)}
            class="text-base-content/50 hover:text-base-content transition-colors shrink-0 ml-4"
            aria-label="Close"
          >
            <CoreComponents.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <%!-- Body --%>
        <div class="p-6 flex-1 overflow-y-auto">
          {render_slot(@inner_block)}
        </div>

        <%!-- Footer --%>
        <div :if={@footer != []} class="flex items-center justify-end gap-2 px-6 py-4 border-t border-neutral shrink-0">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  # Handles both JS structs (JS-state) and event name strings (server-state)
  defp cancel_event(nil), do: nil
  defp cancel_event(%JS{} = js), do: js
  defp cancel_event(event) when is_binary(event), do: JS.push(%JS{}, event)

  defp modal_size_classes(size) do
    case size do
      "sm" -> "max-w-sm max-h-[80vh]"
      "md" -> "max-w-lg max-h-[80vh]"
      "lg" -> "max-w-2xl max-h-[85vh]"
      "xl" -> "max-w-4xl max-h-[90vh]"
      "xxl" -> "max-w-6xl max-h-[90vh]"
      "full" -> "max-w-full w-full h-full m-0 rounded-none"
    end
  end

  @doc """
  Shows a JS-state modal with fade-in transition.
  """
  @spec show_modal(Phoenix.LiveView.JS.t(), String.t()) :: Phoenix.LiveView.JS.t()
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(
      to: "##{id}",
      display: "flex",
      transition: {"transition-opacity ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  @doc """
  Hides a JS-state modal with fade-out transition.
  """
  @spec hide_modal(Phoenix.LiveView.JS.t(), String.t()) :: Phoenix.LiveView.JS.t()
  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}",
      transition: {"transition-opacity ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
