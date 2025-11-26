defmodule PremiereEcouteWeb.Components.Modal do
  @moduledoc """
  Modal dialog components with consistent styling and behavior.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders a modal dialog with backdrop and consistent styling.
  Uses client-side JS for show/hide without server state.

  ## Examples

      <.modal id="my-modal" on_cancel={hide_modal("my-modal")}>
        <:header>
          Modal Title
        </:header>
        <p>Modal content goes here</p>
        <:footer>
          <button phx-click="save">Save</button>
          <button phx-click={hide_modal("my-modal")}>Cancel</button>
        </:footer>
      </.modal>

      <!-- To show the modal -->
      <button phx-click={show_modal("my-modal")}>Open Modal</button>
  """
  attr :id, :string, required: true
  attr :on_cancel, JS, default: nil
  attr :size, :string, default: "md", values: ~w(sm md lg xl xxl full), doc: "Modal size"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header, doc: "Modal header content"
  slot :inner_block, required: true, doc: "Modal body content"
  slot :footer, doc: "Modal footer content"

  def modal(assigns) do
    assigns = assign(assigns, :on_cancel, assigns.on_cancel || hide_modal(assigns.id))

    ~H"""
    <style>
      @keyframes synthwave-glow {
        0% { filter: brightness(1) saturate(1); }
        100% { filter: brightness(1.1) saturate(1.2); }
      }
    </style>
    <div
      id={@id}
      class="hidden fixed inset-0 flex items-center justify-center z-50"
      style="backdrop-filter: blur(8px);"
      phx-click={@on_cancel}
      {@rest}
    >
      <div
        id={"#{@id}-content"}
        class={[
          "bg-surface-elevated rounded-lg shadow-xl mx-4 flex flex-col relative",
          modal_size_classes(@size),
          @class
        ]}
        style="box-shadow: -25px 35px 120px rgba(0, 255, 255, 0.3), 0 40px 140px rgba(255, 20, 147, 0.25), 25px 35px 120px rgba(138, 43, 226, 0.3), 0 50px 160px rgba(255, 255, 255, 0.15); animation: synthwave-glow 3s ease-in-out infinite alternate;"
      >
        <!-- Close button -->
        <button type="button" phx-click={@on_cancel} class="absolute top-4 right-4 text-surface-muted hover:text-surface-primary z-10">
          <CoreComponents.icon name="hero-x-mark" class="w-6 h-6" />
        </button>
        
    <!-- Content -->
        <div class="p-6">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  defp modal_size_classes(size) do
    case size do
      "sm" -> "max-w-sm max-h-[80vh]"
      "md" -> "max-w-md max-h-[80vh]"
      "lg" -> "max-w-2xl max-h-[80vh]"
      "xl" -> "max-w-4xl max-h-[80vh]"
      "xxl" -> "max-w-6xl max-h-[80vh]"
      "full" -> "max-w-full w-full h-full m-0 rounded-none"
    end
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(
      to: "##{id}",
      display: "flex",
      transition: {"transition-opacity ease-out duration-700", "opacity-0", "opacity-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}",
      transition: {"transition-opacity ease-in duration-500", "opacity-100", "opacity-0"}
    )
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
